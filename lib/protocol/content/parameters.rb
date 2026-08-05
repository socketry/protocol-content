# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "default"
require_relative "parameters/type"
require_relative "parameters/result"
require_relative "parameters/declarations"
require_relative "parameters/model"
require_relative "parameters/builder"

module Protocol
	module Content
		# Builds parameter models for filtering, conversion, and validation.
		module Parameters
			# The built-in parameter type conversions.
			TYPES = {
				Integer => ->(value) do
					# Reject non-string values rather than relying on implicit numeric coercion:
					unless value.is_a?(String)
						raise TypeError
					end
					
					Integer(value, 10)
				end,
				Float => ->(value){Float(value)},
			}.freeze
			
			# Build an immutable parameter model.
			# @parameter parser [Parser] The content parser.
			# @parameter types [Hash] The available type conversions.
			# @parameter strict [Boolean] Whether unknown fields should produce validation errors.
			# @yields The parameter declarations.
			# @returns [Model] The frozen parameter model.
			def self.build(parser: Parser.default, types: TYPES, strict: false, &block)
				return Builder.new(parser:, types:, strict:).build(&block)
			end
		end
	end
end
