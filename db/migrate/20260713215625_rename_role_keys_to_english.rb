class RenameRoleKeysToEnglish < ActiveRecord::Migration[8.0]
  RENAMES = {
    "cadastro" => "registration_operator",
    "expedicao" => "expedition_operator",
    "fila" => "queue_operator"
  }.freeze

  def up
    RENAMES.each do |old_key, new_key|
      execute <<~SQL.squish
        UPDATE roles SET key = #{quote(new_key)} WHERE key = #{quote(old_key)}
      SQL
    end
  end

  def down
    RENAMES.each do |old_key, new_key|
      execute <<~SQL.squish
        UPDATE roles SET key = #{quote(old_key)} WHERE key = #{quote(new_key)}
      SQL
    end
  end
end
