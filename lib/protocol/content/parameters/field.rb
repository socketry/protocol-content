# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			# Common behavior for fields in a parameter model.
			class Field
				def initialize(name, required:)
					@name = -name.to_s
					@required = required
				end
				
				attr :name
				
				def required?
					return @required
				end
				
				def upload_field(path)
					return nil
				end
				
			end
			
			class ValueField < Field
				def initialize(name, type, required:, nullable:)
					super(name, required:)
					@type = type
					@nullable = nullable
				end
				
				def apply(value, output, errors, path)
					value = Value.materialize(value)
					
					# Reject nil unless the field is explicitly nullable:
					if value.nil?
						if @nullable
							output[@name] = nil
						else
							errors << Error.new(path, :invalid_type, expected: Type.expected(@type), value: value)
						end
						
						return
					end
					
					# Treat input conversion failures as validation errors:
					output[@name] = @type.call(value)
				rescue ArgumentError, TypeError
					errors << Error.new(path, :invalid_type, expected: Type.expected(@type), value: value)
				end
				
			end
			
			class UploadField < Field
				def initialize(name, required:, multiple:, accept:, size_limit:)
					super(name, required:)
					@multiple = multiple
					@accept = accept
					@size_limit = size_limit
				end
				
				def process(name, upload)
					upload = Upload.new(upload, size_limit: @size_limit)
					
					if @accept
						media_type = upload.media_type
						
						unless media_type
							return Value::Invalid.new(:unsupported_media_type, media_type:, accepted: @accept)
						end
						
						unless @accept.include?(media_type)
							return Value::Invalid.new(:unsupported_media_type, media_type:, accepted: @accept)
						end
					end
					
					begin
						stored = yield(name, upload)
						upload.discard
						return Value::Uploaded.new(stored)
					rescue Upload::LimitError
						return Value::Invalid.new(:too_large, limit: upload.size_limit, size: upload.size)
					end
				end
				
				def upload_field(path)
					if @multiple
						# Upload collections require anonymous array notation:
						accepted = (path == [""])
					else
						accepted = path.empty?
					end
					
					if accepted
						return self
					end
					
					return nil
				end
				
				def apply(value, output, errors, path)
					if @multiple
						return apply_multiple(value, output, errors, path)
					end
					
					apply_upload(value, errors, path) do |stored|
						output[@name] = stored
					end
				end
				
				private
				
				# Apply an upload outcome, rejecting values which do not implement the outcome interface:
				def apply_upload(value, errors, path, &block)
					if value.respond_to?(:apply_upload)
						return value.apply_upload(errors, path, &block)
					end
					
					errors << Error.new(path, :invalid_type, expected: :upload, value: Value.materialize(value))
					return false
				end
				
				def apply_multiple(value, output, errors, path)
					# Upload collections must be represented as arrays by the content parser:
					unless value.is_a?(Array)
						errors << Error.new(path, :invalid_type, expected: Array, value: Value.materialize(value))
						return
					end
					
					# Omit collections containing only uploads which were not handled:
					if value.any? && value.all?{|item| item.equal?(Value::OMITTED)}
						if @required
							errors << Error.new(path, :required)
						end
						
						return
					end
					
					result = []
					submitted = false
					
					value.each_with_index do |item, index|
						if apply_upload(item, errors, path + [index]){|stored| result << stored}
							submitted = true
						end
					end
					
					# Avoid reporting a required error when an upload was submitted but rejected:
					if @required && result.empty? && !submitted
						errors << Error.new(path, :required)
					end
					
					output[@name] = result
				end
				
			end
			
			class ArrayField < Field
				def initialize(name, type, model, required:, nullable:)
					super(name, required:)
					@type = type
					@model = model
					@nullable = nullable
				end
				
				def upload_field(path)
					# Uploads in arrays must target a declared field on an anonymous element:
					unless @model
						return nil
					end
					
					index, *remaining = path
					
					unless index&.empty?
						return nil
					end
					
					return @model.upload_field(remaining)
				end
				
				def apply(value, output, errors, path)
					# Validate the array itself before processing its elements:
					if value.nil?
						if @nullable
							output[@name] = nil
						else
							errors << Error.new(path, :invalid_type, expected: Array, value: value)
						end
						
						return
					end
					
					unless value.is_a?(Array)
						errors << Error.new(path, :invalid_type, expected: Array, value: value)
						return
					end
					
					result = []
					
					value.each_with_index do |item, index|
						item_path = path + [index]
						
						# Ignore uploads which were not accepted by the field:
						if item.equal?(Value::OMITTED)
							next
						end
						
						# Nested arrays validate each element as its own argument hierarchy:
						if @model
							result << @model.apply(item, errors, item_path)
						elsif @type
							# Typed arrays reject nil rather than passing it to coercion:
							if item.nil?
								errors << Error.new(item_path, :invalid_type, expected: Type.expected(@type), value: item)
								next
							end
							
							begin
								item = Value.materialize(item)
								item = @type.call(item)
								result << item
							rescue ArgumentError, TypeError
								errors << Error.new(item_path, :invalid_type, expected: Type.expected(@type), value: item)
							end
						else
							result << Value.materialize(item)
						end
					end
					
					output[@name] = result
				end
				
				def freeze
					return self if self.frozen?
					
					if @model
						@model.freeze
					end
					
					super
				end
				
			end
			
			class NestedField < Field
				def initialize(name, model, required:, nullable:)
					super(name, required:)
					@model = model
					@nullable = nullable
				end
				
				def upload_field(path)
					unless @model
						return nil
					end
					
					return @model.upload_field(path)
				end
				
				def apply(value, output, errors, path)
					# Nested fields require a key/value hierarchy:
					if value.nil?
						if @nullable
							output[@name] = nil
						else
							errors << Error.new(path, :invalid_type, expected: Hash, value: value)
						end
						
						return
					end
					
					unless value.is_a?(Hash)
						errors << Error.new(path, :invalid_type, expected: Hash, value: value)
						return
					end
					
					if @model
						output[@name] = @model.apply(value, errors, path)
					else
						output[@name] = Value.materialize(value)
					end
				end
				
				def freeze
					return self if self.frozen?
					
					if @model
						@model.freeze
					end
					
					super
				end
			end
			
			private_constant :Field, :ValueField, :UploadField, :ArrayField, :NestedField
		end
	end
end
