# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			# Common behavior for fields in a parameter model.
			class Field
				def initialize(name, required:)
					@name = name
					@required = required
				end
				
				attr :name
				
				def required?
					return @required
				end
				
				def accepts_upload?(path)
					return false
				end
				
				def freeze
					@name.freeze
					super
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
				def initialize(name, required:, multiple:)
					super(name, required:)
					@multiple = multiple
				end
				
				def accepts_upload?(path)
					if @multiple
						# Upload collections require anonymous array notation:
						return path == [""]
					else
						return path.empty?
					end
				end
				
				def apply(value, output, errors, path)
					if @multiple
						return apply_multiple(value, output, errors, path)
					end
					
					# Only values produced by an accepted upload handler are valid:
					if value.is_a?(Value::Uploaded)
						output[@name] = value.value
					else
						errors << Error.new(path, :invalid_type, expected: :upload, value: Value.materialize(value))
					end
				end
				
				private
				
				def apply_multiple(value, output, errors, path)
					# Upload collections must be represented as arrays by the content parser:
					unless value.is_a?(Array)
						errors << Error.new(path, :invalid_type, expected: Array, value: Value.materialize(value))
						return
					end
					
					result = []
					
					value.each_with_index do |item, index|
						case item
						when Value::Uploaded
							result << item.value
						when Value::OMITTED
							# Unhandled uploads are consumed by the parser and omitted here:
							next
						else
							errors << Error.new(path + [index], :invalid_type, expected: :upload, value: Value.materialize(item))
						end
					end
					
					# Required collections need at least one successfully handled upload:
					if @required && result.empty?
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
				
				def accepts_upload?(path)
					# Uploads in arrays must target a declared field on an anonymous element:
					unless @model
						return false
					end
					
					index, *remaining = path
					
					unless index&.empty?
						return false
					end
					
					return @model.accepts_upload?(remaining)
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
				
				def accepts_upload?(path)
					unless @model
						return false
					end
					
					return @model.accepts_upload?(path)
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
