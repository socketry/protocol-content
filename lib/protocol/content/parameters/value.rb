# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			module Value
				class Omitted
					def apply_upload(errors, path)
						return false
					end
				end
				
				OMITTED = Omitted.new.freeze
				
				class Invalid
					def initialize(code, **details)
						@code = code
						@details = details
					end
					
					attr :code
					attr :details
					
					def apply_upload(errors, path)
						errors << Error.new(path, @code, **@details)
						return true
					end
				end
				
				class Uploaded
					def initialize(value)
						@value = value
					end
					
					attr :value
					
					def apply_upload(errors, path)
						yield(@value)
						return true
					end
				end
				
				# Apply an upload outcome, rejecting values which do not implement the outcome interface:
				def self.apply_upload(value, errors, path, &block)
					if value.respond_to?(:apply_upload)
						return value.apply_upload(errors, path, &block)
					end
					
					errors << Error.new(path, :invalid_type, expected: :upload, value: materialize(value))
					return false
				end
				
				def self.materialize(value)
					case value
					when Hash
						result = {}
						value.each do |key, item|
							# Remove omitted uploads while preserving the surrounding hierarchy:
							unless item.equal?(OMITTED)
								result[key.to_s] = materialize(item)
							end
						end
						return result
					when Array
						# Remove omitted uploads while preserving accepted array values:
						return value.filter_map do |item|
							unless item.equal?(OMITTED)
								materialize(item)
							end
						end
					else
						return value
					end
				end
			end
			
			private_constant :Value
		end
	end
end
