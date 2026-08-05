# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			# The result of parsing and validating content parameters.
			class Result
				# Initialize the result.
				# @parameter value [Hash] The converted and filtered value.
				# @parameter errors [Array(Error)] The validation errors.
				def initialize(value, errors)
					@value = value
					@errors = errors.freeze
				end
				
				# The converted and filtered value.
				attr :value
				
				# The validation errors.
				attr :errors
				
				# Fetch an entry from the result value.
				# @parameter key [Object] The value key.
				# @returns [Object | Nil] The corresponding value.
				def [](key)
					return @value[key]
				end
				
				# Fetch an entry nested within the result value.
				# @parameter path [Array(Object)] The nested value path.
				# @returns [Object | Nil] The corresponding value.
				def dig(*path)
					return @value.dig(*path)
				end
				
				# Whether the parameters are valid.
				# @returns [Boolean] True when there are no validation errors.
				def valid?
					return @errors.empty?
				end
			end
		end
	end
end
