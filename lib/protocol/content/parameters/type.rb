# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			# Converts input values to a specific application type.
			class Type
				# Initialize a type converter.
				# @parameter type [Object] The expected converted type.
				# @yields {|value| ...} The conversion operation.
				def initialize(type, &converter)
					@type = type
					@converter = converter
				end
				
				# The expected converted type.
				attr :type
				
				# Convert a value to the declared type.
				# @parameter value [Object] The input value.
				# @returns [Object] The converted value.
				# @raises [TypeError] If the value cannot be converted.
				def convert(value)
					# Preserve values which already have the expected type:
					if @type === value
						return value
					end
					
					if @converter
						value = @converter.call(value)
						
						# Ensure converters produce the type they declare:
						if @type === value
							return value
						end
					end
					
					raise TypeError, "Could not convert #{value.inspect} to #{@type}!"
				end
			end
			
			private_constant :Type
		end
	end
end
