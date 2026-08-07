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
					@path = path
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
