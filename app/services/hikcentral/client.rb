require "net/http"
require "uri"
require "openssl"
require "base64"
require "digest/md5"
require "json"

module Hikcentral
  # Signs and sends requests to the HikCentral OpenAPI using its AK/SK
  # HMAC-SHA256 scheme (developer guide section 3.2) — HikCentral has no
  # Ruby SDK, so this hand-builds the signature the same way Twilio's own
  # gem builds its auth internally.
  class Client
    class RequestError < StandardError; end

    ADD_VEHICLE_PATH = "/artemis/api/resource/v1/vehicle/single/add"
    ACCEPT = "application/json"
    CONTENT_TYPE = "application/json"

    def initialize(
      base_url: Integrations::Config.for(:hikcentral).base_url,
      app_key: Integrations::Config.for(:hikcentral).app_key,
      app_secret: Integrations::Config.for(:hikcentral).app_secret,
      vehicle_group_index_code: Integrations::Config.for(:hikcentral).vehicle_group_index_code,
      operator_user_id: Integrations::Config.for(:hikcentral).operator_user_id
    )
      @base_url = base_url
      @app_key = app_key
      @app_secret = app_secret
      @vehicle_group_index_code = vehicle_group_index_code
      @operator_user_id = operator_user_id
    end

    def add_vehicle(plate_no:, effective_date:, expired_date:, person_given_name: nil, phone_no: nil)
      body = {
        plateNo: plate_no,
        vehicleGroupIndexCode: @vehicle_group_index_code,
        effectiveDate: format_time(effective_date),
        expiredDate: format_time(expired_date)
      }
      body[:personGivenName] = person_given_name if person_given_name.present?
      body[:phoneNo] = phone_no if phone_no.present?

      post(ADD_VEHICLE_PATH, body)
    end

    private

    def format_time(time)
      time.strftime("%Y-%m-%dT%H:%M:%S%:z")
    end

    def post(path, body_hash)
      body = body_hash.to_json
      date = Time.now.httpdate
      timestamp = (Time.now.to_f * 1000).to_i
      content_md5 = Base64.strict_encode64(Digest::MD5.digest(body))
      signature = sign(path: path, date: date, timestamp: timestamp, content_md5: content_md5)

      request = build_request(path: path, body: body, date: date, timestamp: timestamp, content_md5: content_md5, signature: signature)
      response = http_client(URI.join(@base_url, path)).request(request)
      parse!(response)
    end

    # Signature string per developer guide section 3.2: METHOD, Accept,
    # Content-MD5, Content-Type, and Date each end with "\n", followed by the
    # signed custom headers (alphabetical, "name:value\n" each), followed
    # directly by the URI with no trailing newline.
    def sign(path:, date:, timestamp:, content_md5:)
      string_to_sign = [
        "POST",
        ACCEPT,
        content_md5,
        CONTENT_TYPE,
        date,
        "x-ca-key:#{@app_key}\nx-ca-timestamp:#{timestamp}\n#{path}"
      ].join("\n")

      Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", @app_secret, string_to_sign))
    end

    def build_request(path:, body:, date:, timestamp:, content_md5:, signature:)
      request = Net::HTTP::Post.new(path)
      request["Accept"] = ACCEPT
      request["Content-MD5"] = content_md5
      request["Content-Type"] = CONTENT_TYPE
      request["Date"] = date
      request["X-Ca-Key"] = @app_key
      request["X-Ca-Timestamp"] = timestamp.to_s
      request["X-Ca-Signature"] = signature
      request["X-Ca-Signature-Headers"] = "x-ca-key,x-ca-timestamp"
      request["userId"] = @operator_user_id
      request.body = body
      request
    end

    def http_client(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 10
      http
    end

    def parse!(response)
      data = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise RequestError, "HikCentral request failed: HTTP #{response.code}, non-JSON body"
      end

      unless response.is_a?(Net::HTTPSuccess) && data["code"] == "0"
        raise RequestError, "HikCentral request failed: HTTP #{response.code}, code=#{data["code"]}, msg=#{data["msg"]}"
      end

      data
    end
  end
end
