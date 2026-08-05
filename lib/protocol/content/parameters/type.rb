# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		class Parameters
			# Converts input values to a specific application type.
			class Type
				@types = {}
				
				# Register a converter for a type.
				# @parameter type [Object] The declared type.
				# @yields {|value| ...} The conversion operation.
				# @returns [Type] The registered type converter.
				def self.register(type, &converter)
					return @types[type] = new(type, &converter)
				end
				
				# Resolve a declared type to a converter.
				# @parameter type [Object] The declared type or converter.
				# @returns [Type | Object] A value responding to `#call`.
				def self.for(type)
					# Preserve custom converters without wrapping them:
					if type.respond_to?(:call)
						return type
					end
					
					return @types.fetch(type){new(type)}
				end
				
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
			
			Type.register(String) do |value|
				String(value)
			end
			
			Type.register(Integer) do |value|
				# Reject non-string values rather than relying on implicit numeric coercion:
				unless value.is_a?(String)
					raise TypeError
				end
				
				Integer(value, 10)
			end
			
			Type.register(Float) do |value|
				Float(value)
			end
		end
	end
end
