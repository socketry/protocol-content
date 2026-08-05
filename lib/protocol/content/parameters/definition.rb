# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "type"

module Protocol
	module Content
		class Parameters
			OMITTED = Object.new.freeze
			
			class UploadedValue
				def initialize(value)
					@value = value
				end
				
				attr :value
			end
			
			module Values
				def self.convert(type, value)
					if type.respond_to?(:convert)
						return type.convert(value)
					else
						return type.call(value)
					end
				end
				
				def self.expected_type(type)
					if type.respond_to?(:type)
						return type.type
					else
						return type
					end
				end
				
				def self.materialize(value)
					case value
					when Hash
						result = {}
						value.each do |key, item|
							# Remove omitted uploads while preserving the surrounding hierarchy:
							unless item.equal?(OMITTED)
								result[key.to_s] = materialize(item)
							end
						end
						return result
					when Array
						# Remove omitted uploads while preserving accepted array values:
						return value.filter_map do |item|
							unless item.equal?(OMITTED)
								materialize(item)
							end
						end
					else
						return value
					end
				end
			end
			
			class Field
				def initialize(name, type, required:, nullable:)
					@name = name
					@type = Type.for(type)
					@required = required
					@nullable = nullable
				end
				
				attr :name
				
				def required?
					return @required
				end
				
				def apply(value, output, errors, path)
					value = Values.materialize(value)
					
					# Reject nil unless the field is explicitly nullable:
					if value.nil?
						if @nullable
							output[@name] = nil
						else
							errors << Error.new(path, :invalid_type, expected: Values.expected_type(@type), value: value)
						end
						
						return
					end
					
					# Treat input conversion failures as validation errors:
					output[@name] = Values.convert(@type, value)
				rescue ArgumentError, TypeError
					errors << Error.new(path, :invalid_type, expected: Values.expected_type(@type), value: value)
				end
				
				def freeze
					@name.freeze
					super
				end
				
			end
			
			class Upload
				def initialize(name, required:)
					@name = name
					@required = required
				end
				
				attr :name
				
				def required?
					return @required
				end
				
				def accepts_upload?(path)
					return path.empty?
				end
				
				def apply(value, output, errors, path)
					# Only values produced by an accepted upload handler are valid:
					if value.is_a?(UploadedValue)
						output[@name] = value.value
					else
						errors << Error.new(path, :invalid_type, expected: :upload, value: Values.materialize(value))
					end
				end
				
				def freeze
					@name.freeze
					super
				end
			end
			
			class ArrayField
				def initialize(name, type, definition, required:, nullable:)
					@name = name
					
					if type
						@type = Type.for(type)
					end
					
					@definition = definition
					@required = required
					@nullable = nullable
				end
				
				attr :name
				
				def required?
					return @required
				end
				
				def accepts_upload?(path)
					# Uploads in arrays must target a declared field on an anonymous element:
					unless @definition
						return false
					end
					
					index, *remaining = path
					
					unless index&.empty?
						return false
					end
					
					return @definition.accepts_upload?(remaining)
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
						
						# Ignore uploads which were not accepted by the declaration:
						if item.equal?(OMITTED)
							next
						end
						
						# Nested arrays validate each element as its own argument hierarchy:
						if @definition
							result << @definition.apply(item, errors, item_path)
						elsif @type
							# Typed arrays reject nil rather than passing it to coercion:
							if item.nil?
								errors << Error.new(item_path, :invalid_type, expected: Values.expected_type(@type), value: item)
								next
							end
							
							begin
								item = Values.materialize(item)
								item = Values.convert(@type, item)
								result << item
							rescue ArgumentError, TypeError
								errors << Error.new(item_path, :invalid_type, expected: Values.expected_type(@type), value: item)
							end
						else
							result << Values.materialize(item)
						end
					end
					
					output[@name] = result
				end
				
				def freeze
					@name.freeze
					
					if @definition
						@definition.freeze
					end
					
					super
				end
				
			end
			
			class Nested
				def initialize(name, definition, required:, nullable:)
					@name = name
					@definition = definition
					@required = required
					@nullable = nullable
				end
				
				attr :name
				
				def required?
					return @required
				end
				
				def accepts_upload?(path)
					unless @definition
						return false
					end
					
					return @definition.accepts_upload?(path)
				end
				
				def apply(value, output, errors, path)
					# Nested declarations require a key/value hierarchy:
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
					
					if @definition
						output[@name] = @definition.apply(value, errors, path)
					else
						output[@name] = Values.materialize(value)
					end
				end
				
				def freeze
					@name.freeze
					
					if @definition
						@definition.freeze
					end
					
					super
				end
			end
			
			class Definition
				def initialize(strict: false)
					@strict = strict
					@declarations = {}
				end
				
				attr :strict
				
				def field(name, type = Object, required: false, nullable: false)
					name = name.to_s
					return add(Field.new(name, type, required:, nullable:))
				end
				
				def upload(name, required: false)
					name = name.to_s
					return add(Upload.new(name, required:))
				end
				
				def array(name, type = nil, required: false, nullable: false, strict: @strict, &block)
					name = name.to_s
					
					if block
						# A block defines the element shape and cannot be combined with conversion:
						if type
							raise ArgumentError, "An array cannot declare both an element type and nested fields!"
						end
						
						definition = Definition.new(strict:)
						definition.instance_eval(&block)
					end
					
					return add(ArrayField.new(name, type, definition, required:, nullable:))
				end
				
				def nested(name, required: false, nullable: false, strict: @strict, &block)
					name = name.to_s
					
					if block
						definition = Definition.new(strict:)
						definition.instance_eval(&block)
					end
					
					return add(Nested.new(name, definition, required:, nullable:))
				end
				
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
				
				def freeze
					@declarations.each_value(&:freeze)
					@declarations.freeze
					super
				end
				
				private
				
				def add(declaration)
					# Reject ambiguous declarations for the same input name:
					if @declarations.key?(declaration.name)
						raise ArgumentError, "Parameter #{declaration.name.inspect} is already declared!"
					end
					
					@declarations[declaration.name] = declaration
					return declaration
				end
			end
			
			private_constant :OMITTED, :UploadedValue, :Values, :Type, :Field, :Upload, :ArrayField, :Nested, :Definition
		end
	end
end
