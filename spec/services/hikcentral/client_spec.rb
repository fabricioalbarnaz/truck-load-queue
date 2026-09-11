require "rails_helper"

RSpec.describe Hikcentral::Client do
  subject(:client) do
    described_class.new(
      base_url: "https://hikcentral.example.com:443",
      app_key: "test-app-key",
      app_secret: "test-app-secret",
      vehicle_group_index_code: "1",
      operator_user_id: "admin"
    )
  end

  let(:add_vehicle_url) { "https://hikcentral.example.com:443/artemis/api/resource/v1/vehicle/single/add" }
  let(:effective_date) { Time.zone.local(2026, 1, 1, 0, 0, 0) }
  let(:expired_date) { effective_date + 5.years }

  def request_headers(request)
    request.headers.transform_keys(&:downcase)
  end

  describe "#add_vehicle" do
    it "signs and posts the request, returning the parsed response on success" do
      stub_request(:post, add_vehicle_url)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { code: "0", msg: "Success", data: { vehicleId: "20", plateNo: "ABC1D23" } }.to_json
        )

      result = client.add_vehicle(
        plate_no: "ABC1D23", person_given_name: "Maria", phone_no: "+5511999999999",
        effective_date: effective_date, expired_date: expired_date
      )

      expect(result["data"]["vehicleId"]).to eq("20")
      expect(WebMock).to have_requested(:post, add_vehicle_url).with { |request|
        body = JSON.parse(request.body)
        headers = request_headers(request)

        body["plateNo"] == "ABC1D23" &&
          body["vehicleGroupIndexCode"] == "1" &&
          body["personGivenName"] == "Maria" &&
          body["phoneNo"] == "+5511999999999" &&
          body["effectiveDate"] == effective_date.strftime("%Y-%m-%dT%H:%M:%S%:z") &&
          body["expiredDate"] == expired_date.strftime("%Y-%m-%dT%H:%M:%S%:z") &&
          headers["x-ca-key"] == "test-app-key" &&
          headers["x-ca-signature-headers"] == "x-ca-key,x-ca-timestamp" &&
          headers["x-ca-signature"].present? &&
          headers["x-ca-timestamp"].present? &&
          headers["userid"] == "admin"
      }
    end

    it "omits optional person/phone fields when not given" do
      stub_request(:post, add_vehicle_url).to_return(status: 200, body: { code: "0", msg: "Success" }.to_json)

      client.add_vehicle(plate_no: "XYZ9Z99", effective_date: effective_date, expired_date: expired_date)

      expect(WebMock).to have_requested(:post, add_vehicle_url).with { |request|
        body = JSON.parse(request.body)
        !body.key?("personGivenName") && !body.key?("phoneNo")
      }
    end

    it "raises RequestError when HikCentral returns a non-zero status code" do
      stub_request(:post, add_vehicle_url)
        .to_return(status: 200, body: { code: "0x02401000", msg: "No AppKey is configured" }.to_json)

      expect {
        client.add_vehicle(plate_no: "ABC1D23", effective_date: effective_date, expired_date: expired_date)
      }.to raise_error(Hikcentral::Client::RequestError, /0x02401000/)
    end

    it "raises RequestError on a non-2xx HTTP response" do
      stub_request(:post, add_vehicle_url).to_return(status: 500, body: "Internal Server Error")

      expect {
        client.add_vehicle(plate_no: "ABC1D23", effective_date: effective_date, expired_date: expired_date)
      }.to raise_error(Hikcentral::Client::RequestError)
    end
  end
end
