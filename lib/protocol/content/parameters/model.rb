# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/multipart/form_data"
require "protocol/url/encoding"

module Protocol
	module Content
		module Parameters
			# An immutable model for parsing, filtering, and validating parameters.
			class Model
				# Initialize a parameter model.
				# @parameter parser [Parser] The content parser.
				# @parameter declarations [Hash] The parameter declarations.
				# @parameter strict [Boolean] Whether unknown fields should produce validation errors.
				def initialize(parser, declarations, strict: false)
					@parser = parser
					@declarations = declarations
					@strict = strict
				end
				
				# Parse, filter, and validate content parameters.
				# @parameter media_type [String | Protocol::Media::Type | Nil] The content media type.
				# @parameter input [Object] The readable content input.
				# @yields {|name, upload| ...} Each streaming upload. Its return value is inserted into the parsed value.
				# @returns [Result] The parsed value and validation errors.
				def parse(media_type, input, &upload_handler)
					value = @parser.parse(media_type, input) do |name, item|
						if item.is_a?(Protocol::Multipart::FormData::Upload)
							path = Protocol::URL::Encoding.split(name)
							
							# Only process uploads accepted by an explicit declaration:
							if upload_handler && accepts_upload?(path)
								UploadedValue.new(upload_handler.call(name, item))
							else
								OMITTED
							end
						else
							item
						end
					end
					
					errors = []
					value = apply(value, errors)
					return Result.new(value, errors)
				end
				
				# Parse content parameters, raising when validation fails.
				# @parameter media_type [String | Protocol::Media::Type | Nil] The content media type.
				# @parameter input [Object] The readable content input.
				# @yields {|name, upload| ...} Each streaming upload. Its return value is inserted into the parsed value.
				# @returns [Hash] The valid value.
				# @raises [ValidationError] If validation fails.
				def parse!(media_type, input, &block)
					result = parse(media_type, input, &block)
					
					if result.valid?
						return result.value
					end
					
					raise ValidationError, result
				end
				
				# Apply this model to an existing argument hierarchy.
				# @parameter value [Object] The parameter hierarchy.
				# @parameter errors [Array(Error)] The validation error destination.
				# @parameter path [Array(String | Integer)] The current argument path.
				# @returns [Hash] The filtered and converted value.
				def apply(value, errors, path = [])
					# Parameter declarations always apply to a key/value hierarchy:
					unless value.is_a?(Hash)
						errors << Error.new(path, :invalid_type, expected: Hash, value: value)
						return {}
					end
					
					# Normalize keys before matching them against declarations:
					input = {}
					value.each{|key, item| input[key.to_s] = item}
					output = {}
					
					# Apply declared values and collect missing required parameters:
					@declarations.each do |name, declaration|
						item_path = path + [name]
						
						if input.key?(name)
							item = input.delete(name)
							
							if item.equal?(OMITTED)
								if declaration.required?
									errors << Error.new(item_path, :required)
								end
							else
								declaration.apply(item, output, errors, item_path)
							end
						elsif declaration.required?
							errors << Error.new(item_path, :required)
						end
					end
					
					# Reject remaining undeclared values when strict validation is enabled:
					input.each do |name, item|
						if item.equal?(OMITTED)
							if @strict
								errors << Error.new(path + [name], :unknown)
							end
							
							next
						end
						
						if @strict
							errors << Error.new(path + [name], :unknown)
						end
					end
					
					return output
				end
				
				# Whether an upload path is explicitly accepted by this model.
				# @parameter path [Array(String)] The decoded upload path.
				# @returns [Boolean] Whether the upload is accepted.
				def accepts_upload?(path)
					# Walk declarations using the decoded components of the form name:
					name, *remaining = path
					
					unless declaration = @declarations[name]
						return false
					end
					
					unless declaration.respond_to?(:accepts_upload?)
						return false
					end
					
					return declaration.accepts_upload?(remaining)
				end
				
				# Freeze this model and its declarations.
				# @returns [self] The frozen model.
				def freeze
					@parser.freeze
					@declarations.each_value(&:freeze)
					@declarations.freeze
					super
				end
			end
		end
	end
end
