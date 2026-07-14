# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

ROLES = {
  "admin" => "Administrador",
  "registration_operator" => "Operador de Cadastro",
  "expedition_operator" => "Operador de Expedição",
  "queue_operator" => "Operador de Fila"
}.freeze

ROLES.each do |key, name|
  Role.find_or_create_by!(key: key) { |role| role.name = name }
end

admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "changeme123")

admin = User.find_or_create_by!(email: admin_email) do |user|
  user.name = "Administrador"
  user.password = admin_password
  user.password_confirmation = admin_password
end

admin_role = Role.find_by!(key: "admin")
UserRole.find_or_create_by!(user: admin, role: admin_role)

puts "Seeded #{Role.count} roles and admin user (#{admin_email})."
