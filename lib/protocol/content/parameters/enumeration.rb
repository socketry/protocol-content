# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			# Converts an exact set of input values to corresponding output values.
			class Enumeration
				# Construct an enumeration from accepted values or an input-to-output mapping.
				# @parameter values [Array(Object)] The accepted values.
				# @parameter options [Hash] Additional input-to-output mappings.
				# @returns [Enumeration] The enumeration converter.
				def self.build(*values, **options)
					mapping = values.to_h{|value| [value, value]}
					mapping.update(options)
					return new(mapping)
				end
				
				# Initialize an enumeration from an input-to-output mapping.
				# @parameter mapping [Hash] The accepted inputs and corresponding outputs.
				def initialize(mapping)
					@mapping = mapping.freeze
				end
				
				# The accepted input values and corresponding output values.
				attr :mapping
				
				# Convert an accepted input value.
				# @parameter value [Object] The input value.
				# @returns [Object] The corresponding output value.
				# @raises [ArgumentError] If the input value is not accepted.
				def call(value)
					if @mapping.key?(value)
						return @mapping[value]
					end
					
					raise ArgumentError, "Invalid enumeration value: #{value.inspect}!"
				end
			end
		end
	end
end
