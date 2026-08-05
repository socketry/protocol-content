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
				def self.materialize(value)
					case value
					when UploadedValue
						return value.value
					when Hash
						result = {}
						value.each do |key, item|
							result[key.to_s] = materialize(item) unless item.equal?(OMITTED)
						end
						return result
					when Array
						return value.filter_map do |item|
							materialize(item) unless item.equal?(OMITTED)
						end
					else
						return value
					end
				end
				
				def self.extract_uploads(value)
					case value
					when UploadedValue
						return value.value, false
					when Hash
						uploads = {}
						regular = false
						
						value.each do |key, item|
							extracted, item_regular = extract_uploads(item)
							uploads[key.to_s] = extracted unless extracted.equal?(OMITTED)
							regular ||= item_regular
						end
						
						return uploads.empty? ? OMITTED : uploads, regular
					when Array
						uploads = []
						regular = false
						
						value.each do |item|
							extracted, item_regular = extract_uploads(item)
							uploads << extracted unless extracted.equal?(OMITTED)
							regular ||= item_regular
						end
						
						return uploads.empty? ? OMITTED : uploads, regular
					when OMITTED
						return OMITTED, false
					else
						return OMITTED, true
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
					if value.is_a?(UploadedValue)
						output[@name] = value.value
						return
					end
					
					value = Values.materialize(value)
					
					if value.nil?
						if @nullable
							output[@name] = nil
						else
							errors << Error.new(path, :invalid_type, expected: expected_type, value: value)
						end
						
						return
					end
					
					output[@name] = @type.convert(value)
				rescue ArgumentError, TypeError
					errors << Error.new(path, :invalid_type, expected: expected_type, value: value)
				end
				
				def freeze
					@name.freeze
					super
				end
				
				private
				
				def expected_type
					if @type.respond_to?(:type)
						return @type.type
					else
						return @type
					end
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
				
				def apply(value, output, errors, path)
					if value.is_a?(UploadedValue)
						output[@name] = value.value
						return
					end
					
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
					@definition&.freeze
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
				
				def nested(name, required: false, nullable: false, strict: @strict, &block)
					name = name.to_s
					
					if block
						definition = Definition.new(strict:)
						definition.instance_eval(&block)
					end
					
					return add(Nested.new(name, definition, required:, nullable:))
				end
				
				def apply(value, errors, path = [])
					unless value.is_a?(Hash)
						errors << Error.new(path, :invalid_type, expected: Hash, value: value)
						return {}
					end
					
					input = {}
					value.each{|key, item| input[key.to_s] = item}
					output = {}
					
					@declarations.each do |name, declaration|
						item_path = path + [name]
						
						if input.key?(name) && !input[name].equal?(OMITTED)
							declaration.apply(input.delete(name), output, errors, item_path)
						elsif declaration.required?
							errors << Error.new(item_path, :required)
						end
					end
					
					input.each do |name, item|
						next if item.equal?(OMITTED)
						
						uploads, regular = Values.extract_uploads(item)
						output[name] = uploads unless uploads.equal?(OMITTED)
						
						if @strict && regular
							errors << Error.new(path + [name], :unknown)
						end
					end
					
					return output
				end
				
				def freeze
					@declarations.each_value(&:freeze)
					@declarations.freeze
					super
				end
				
				private
				
				def add(declaration)
					if @declarations.key?(declaration.name)
						raise ArgumentError, "Parameter #{declaration.name.inspect} is already declared!"
					end
					
					@declarations[declaration.name] = declaration
					return declaration
				end
			end
			
			private_constant :OMITTED, :UploadedValue, :Values, :Type, :Field, :Nested, :Definition
		end
	end
end
