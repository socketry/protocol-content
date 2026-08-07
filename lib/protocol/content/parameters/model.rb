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
				# @parameter fields [Hash] The parameter fields.
				# @parameter strict [Boolean] Whether unknown fields should produce validation errors.
				def initialize(parser, fields, strict: true)
					@parser = parser
					@fields = fields
					@strict = strict
				end
				
				# The fields in this model, indexed by name.
				attr :fields
				
				# Parse, filter, and validate content parameters.
				# @parameter media_type [String | Protocol::Media::Type | Nil] The content media type.
				# @parameter input [Object] The readable content input.
				# @yields {|name, upload| ...} Each streaming upload. Its return value is inserted into the parsed value.
				# @returns [Result] The parsed value and validation errors.
				def parse(media_type, input, &upload_handler)
					value = @parser.parse(media_type, input) do |name, item|
						if item.is_a?(Protocol::Multipart::FormData::Upload)
							path = Protocol::URL::Encoding.split(name)
							
							# Only process uploads accepted by an explicit field:
							if upload_handler && field = upload_field(path)
								upload = field.prepare(item)
								
								if upload.is_a?(Value::Invalid)
									upload
								else
									begin
										stored = upload_handler.call(name, upload)
										upload.discard
										Value::Uploaded.new(stored)
									rescue Upload::LimitError
										Value::Invalid.new(:too_large, limit: upload.size_limit, size: upload.size)
									end
								end
							else
								Value::OMITTED
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
					# Parameter models always apply to a key/value hierarchy:
					unless value.is_a?(Hash)
						errors << Error.new(path, :invalid_type, expected: Hash, value: value)
						return {}
					end
					
					# Normalize keys before matching them against fields:
					input = {}
					value.each{|key, item| input[key.to_s] = item}
					output = {}
					
					# Apply declared values and collect missing required parameters:
					@fields.each do |name, field|
						item_path = path + [name]
						
						if input.key?(name)
							item = input.delete(name)
							
							if item.equal?(Value::OMITTED)
								if field.required?
									errors << Error.new(item_path, :required)
								end
							else
								field.apply(item, output, errors, item_path)
							end
						elsif field.required?
							errors << Error.new(item_path, :required)
						end
					end
					
					# Reject remaining undeclared values when strict validation is enabled:
					if @strict
						input.each_key do |name|
							errors << Error.new(path + [name], :unknown)
						end
					end
					
					return output
				end
				
				# Whether an upload path is explicitly accepted by this model.
				# @parameter path [Array(String)] The decoded upload path.
				# @returns [Boolean] Whether the upload is accepted.
				def accepts_upload?(path)
					return !!upload_field(path)
				end
				
				# Find the upload field which accepts the given decoded path.
				# @parameter path [Array(String)] The decoded upload path.
				# @returns [UploadField | Nil] The accepting upload field.
				def upload_field(path)
					# Walk fields using the decoded components of the form name:
					name, *remaining = path
					
					unless field = @fields[name]
						return nil
					end
					
					return field.upload_field(remaining)
				end
				
				# Freeze this model and its fields.
				# @returns [self] The frozen model.
				def freeze
					@parser.freeze
					@fields.each_value(&:freeze)
					@fields.freeze
					super
				end
			end
		end
	end
end
