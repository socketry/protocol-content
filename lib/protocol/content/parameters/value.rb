# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			module Value
				OMITTED = Object.new.freeze
				
				class Invalid
					def initialize(code, **details)
						@code = code
						@details = details
					end
					
					attr :code
					attr :details
				end
				
				class Uploaded
					def initialize(value)
						@value = value
					end
					
					attr :value
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
