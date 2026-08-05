# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		module Parameters
			# Builds immutable parameter models using a declaration DSL.
			class Builder
				# Initialize a parameter model builder.
				# @parameter parser [Parser] The content parser.
				# @parameter types [Hash] The available type conversions.
				# @parameter strict [Boolean] Whether unknown fields should produce validation errors.
				def initialize(parser: Parser.default, types: TYPES, strict: true)
					@parser = parser
					@types = types
					@strict = strict
					@declarations = {}
				end
				
				# Evaluate declarations and construct an immutable parameter model.
				# @yields The parameter declarations.
				# @returns [Model] The frozen parameter model.
				def build(&block)
					instance_eval(&block)
					return Model.new(@parser, @declarations, strict: @strict).freeze
				end
				
				# Declare a scalar field.
				# @parameter name [String] The field name.
				# @parameter type [Module | #call] The expected value type or converter.
				# @parameter required [Boolean] Whether the field must be present.
				# @parameter nullable [Boolean] Whether the field may be nil.
				# @returns [Object] The field declaration.
				def field(name, type = Object, required: false, nullable: false)
					name = name.to_s
					return add(Field.new(name, resolve(type), required:, nullable:))
				end
				
				# Declare a streaming file upload.
				# @parameter name [String] The upload field name.
				# @parameter required [Boolean] Whether the upload must be present.
				# @returns [Object] The upload declaration.
				def upload(name, required: false)
					name = name.to_s
					return add(Upload.new(name, required:))
				end
				
				# Declare a collection of streaming file uploads.
				# @parameter name [String] The upload collection field name.
				# @parameter required [Boolean] Whether at least one handled upload must be present.
				# @returns [Object] The upload collection declaration.
				def uploads(name, required: false)
					name = name.to_s
					return add(Uploads.new(name, required:))
				end
				
				# Declare an array of scalar values or nested argument hierarchies.
				# @parameter name [String] The array field name.
				# @parameter type [Module | #call | Nil] The expected element type or converter.
				# @parameter required [Boolean] Whether the array must be present.
				# @parameter nullable [Boolean] Whether the array may be nil.
				# @parameter strict [Boolean] Whether unknown nested fields should produce validation errors.
				# @yields The nested parameter declarations for each array element.
				# @returns [Object] The array declaration.
				def array(name, type = nil, required: false, nullable: false, strict: @strict, &block)
					name = name.to_s
					
					if block
						# A block defines the element shape and cannot be combined with conversion:
						if type
							raise ArgumentError, "An array cannot declare both an element type and nested fields!"
						end
						
						model = nested_model(strict:, &block)
					elsif type
						type = resolve(type)
					end
					
					return add(ArrayField.new(name, type, model, required:, nullable:))
				end
				
				# Declare a nested argument hierarchy. Without a block, all nested values are accepted.
				# @parameter name [String] The nested field name.
				# @parameter required [Boolean] Whether the field must be present.
				# @parameter nullable [Boolean] Whether the field may be nil.
				# @parameter strict [Boolean] Whether unknown nested fields should produce validation errors.
				# @yields The nested parameter declarations.
				# @returns [Object] The nested declaration.
				def nested(name, required: false, nullable: false, strict: @strict, &block)
					name = name.to_s
					
					if block
						model = nested_model(strict:, &block)
					end
					
					return add(Nested.new(name, model, required:, nullable:))
				end
				
				private
				
				def resolve(type)
					# Preserve custom converters without wrapping them:
					if type.respond_to?(:call)
						return type
					end
					
					if converter = @types[type]
						return Type.new(type, &converter)
					end
					
					return Type.new(type)
				end
				
				def nested_model(strict:, &block)
					return self.class.new(parser: @parser, types: @types, strict:).build(&block)
				end
				
				def add(declaration)
					# Reject ambiguous declarations for the same input name:
					if @declarations.key?(declaration.name)
						raise ArgumentError, "Parameter #{declaration.name.inspect} is already declared!"
					end
					
					@declarations[declaration.name] = declaration
					return declaration
				end
			end
		end
	end
end
