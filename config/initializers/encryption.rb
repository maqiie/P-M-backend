# # config/initializers/encryption.rb
# primary_key = Rails.application.credentials.dig(:active_record_encryption, :primary_key)
# deterministic_key = Rails.application.credentials.dig(:active_record_encryption, :deterministic_key)
# key_derivation_salt = Rails.application.credentials.dig(:active_record_encryption, :key_derivation_salt)

# puts "Primary Key: #{primary_key}, Length: #{primary_key.length}" unless primary_key.nil?
# puts "Deterministic Key: #{deterministic_key}, Length: #{deterministic_key.length}" unless deterministic_key.nil?
# puts "Key Derivation Salt: #{key_derivation_salt}, Length: #{key_derivation_salt.length}" unless key_derivation_salt.nil?

# if primary_key.nil? || primary_key.length != 32
#   raise "Primary key is missing or invalid length: #{primary_key.inspect}"
# end

# if deterministic_key.nil? || deterministic_key.length != 32
#   raise "Deterministic key is missing or invalid length: #{deterministic_key.inspect}"
# end

# if key_derivation_salt.nil?
#   raise "Key derivation salt is missing"
# end

# Rails.application.config.active_record.encryption.primary_key = primary_key
# Rails.application.config.active_record.encryption.deterministic_key = deterministic_key
# Rails.application.config.active_record.encryption.key_derivation_salt = key_derivation_salt
