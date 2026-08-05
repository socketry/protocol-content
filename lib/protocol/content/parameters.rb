# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "default"
require_relative "parameters/definition"
require_relative "parameters/result"

require "protocol/multipart/form_data"
require "protocol/url/encoding"

module Protocol
	module Content
		# Parses content into a filtered and validated argument hierarchy.
		class Parameters
			# Build and freeze a parameter definition.
			# @parameter parser [Parser] The content parser.
			# @parameter strict [Boolean] Whether unknown fields should produce validation errors.
			# @yields The parameter declarations.
			# @returns [Parameters] The frozen parameter definition.
			def self.build(parser: Parser.default, strict: false, &block)
				parameters = new(parser:, strict:)
				parameters.instance_eval(&block)
				return parameters.freeze
			end
			
			# Initialize a mutable parameter definition.
			# @parameter parser [Parser] The content parser.
			# @parameter strict [Boolean] Whether unknown fields should produce validation errors.
			def initialize(parser: Parser.default, strict: false)
				@parser = parser
				@definition = Definition.new(strict:)
			end
			
			# Declare a scalar field.
			# @parameter name [String] The field name.
			# @parameter type [Module | #call] The expected value type or converter.
			# @parameter required [Boolean] Whether the field must be present.
			# @parameter nullable [Boolean] Whether the field may be nil.
			# @returns [Object] The field declaration.
			def field(name, type = Object, required: false, nullable: false)
				return @definition.field(name, type, required:, nullable:)
			end
			
			# Declare a streaming file upload.
			# @parameter name [String] The upload field name.
			# @parameter required [Boolean] Whether the upload must be present.
			# @returns [Object] The upload declaration.
			def upload(name, required: false)
				return @definition.upload(name, required:)
			end
			
			# Declare a nested argument hierarchy. Without a block, all nested values are accepted.
			# @parameter name [String] The nested field name.
			# @parameter required [Boolean] Whether the field must be present.
			# @parameter nullable [Boolean] Whether the field may be nil.
			# @parameter strict [Boolean] Whether unknown nested fields should produce validation errors.
			# @yields The nested parameter declarations.
			# @returns [Object] The nested declaration.
			def nested(name, required: false, nullable: false, strict: @definition.strict, &block)
				return @definition.nested(name, required:, nullable:, strict:, &block)
			end
			
			# Parse, filter, and validate content parameters.
			# @parameter media_type [String | Protocol::Media::Type | Nil] The content media type.
			# @parameter input [Object] The readable content input.
			# @yields {|name, upload| ...} Each streaming upload. Its return value is inserted into the arguments.
			# @returns [Result] The parsed arguments and validation errors.
			def parse(media_type, input, &upload_handler)
				arguments = @parser.parse(media_type, input) do |name, value|
					if value.is_a?(Protocol::Multipart::FormData::Upload)
						path = Protocol::URL::Encoding.split(name)
						
						if upload_handler && @definition.accepts_upload?(path)
							UploadedValue.new(upload_handler.call(name, value))
						else
							OMITTED
						end
					else
						value
					end
				end
				
				errors = []
				arguments = @definition.apply(arguments, errors)
				return Result.new(arguments, errors)
			end
			
			# Parse content parameters, raising when validation fails.
			# @parameter media_type [String | Protocol::Media::Type | Nil] The content media type.
			# @parameter input [Object] The readable content input.
			# @yields {|name, upload| ...} Each streaming upload. Its return value is inserted into the arguments.
			# @returns [Hash] The valid arguments.
			# @raises [ValidationError] If validation fails.
			def parse!(media_type, input, &block)
				result = parse(media_type, input, &block)
				return result.arguments if result.valid?
				
				raise ValidationError, result
			end
			
			# Freeze this parameter definition.
			# @returns [self] The frozen parameter definition.
			def freeze
				@parser.freeze
				@definition.freeze
				super
			end
		end
	end
end
