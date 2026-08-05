# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../error"

module Protocol
	module Content
		module Parameters
			# A validation error associated with a specific argument path.
			class Error
				# Initialize the validation error.
				# @parameter path [Array(String | Integer)] The path to the invalid argument.
				# @parameter code [Symbol] The machine-readable error code.
				# @parameter details [Hash] Additional error details.
				def initialize(path, code, **details)
					@path = path.freeze
					@code = code
					@details = details.freeze
				end
				
				# The path to the invalid argument.
				attr :path
				
				# The machine-readable error code.
				attr :code
				
				# Additional error details.
				attr :details
			end
			
			# The result of parsing and validating content parameters.
			class Result
				# Initialize the result.
				# @parameter arguments [Hash] The converted and filtered arguments.
				# @parameter errors [Array(Error)] The validation errors.
				def initialize(arguments, errors)
					@arguments = arguments
					@errors = errors.freeze
				end
				
				# The converted and filtered arguments.
				attr :arguments
				
				# The validation errors.
				attr :errors
				
				# Whether the parameters are valid.
				# @returns [Boolean] True when there are no validation errors.
				def valid?
					return @errors.empty?
				end
			end
			
			# Raised when parsed parameters are invalid.
			class ValidationError < Protocol::Content::Error
				# Initialize the validation error.
				# @parameter result [Result] The invalid parameters result.
				def initialize(result)
					@result = result
					super("Content parameters are invalid!")
				end
				
				# The invalid parameters result.
				attr :result
			end
		end
	end
end
