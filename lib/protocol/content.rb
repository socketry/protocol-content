# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/type"

require_relative "content/version"
require_relative "content/error"
require_relative "content/parser"

module Protocol
	# @namespace
	module Content
		# A representation consists of encoded data and metadata describing that data.
		class Representation
			UNDEFINED = Object.new.freeze
			private_constant :UNDEFINED
			
			PARSER = Parser.new.freeze
			
			# Construct a representation specialization using the given parser.
			# @parameter parser [Parser] The parser used to decode representation values.
			# @returns [Class] A configured representation subclass.
			def self.[](parser)
				klass = Class.new(self)
				klass.const_set(:PARSER, parser)
				return klass
			end
			
			# The parser configured for this representation class.
			# @returns [Parser] The configured parser.
			def self.parser
				self.const_get(:PARSER)
			end
			
			# Construct a representation from a request or response message.
			# @parameter message [Object] A message exposing `headers` and `body`.
			# @parameter parser [Parser] The parser used to decode the representation.
			# @returns [Representation] The representation carried by the message.
			def self.for(message, parser: self.parser)
				return self.new(message, parser: parser)
			end
			
			# Initialize a representation.
			# @parameter message [Object | Nil] The source request or response.
			# @parameter metadata [Object] The representation metadata.
			# @parameter body [Object | Nil] The encoded representation data.
			# @parameter parser [Parser] The parser used to decode the representation.
			# @parameter value [Object] An already decoded representation value.
			def initialize(message = nil, metadata: message&.headers || {}, body: message&.body, parser: self.class.parser, value: UNDEFINED)
				@message = message
				@metadata = metadata
				@body = body
				@parser = parser
				@value = value
				@content_type = UNDEFINED
			end
			
			# The request or response carrying this representation, if available.
			attr :message
			
			# Metadata describing the representation.
			attr :metadata
			
			# The encoded representation body.
			attr :body
			
			# The parser used to decode the representation.
			attr :parser
			
			# The representation media type described by its metadata.
			# @returns [Protocol::Media::Type | Object | Nil] The content type, if present.
			def content_type
				if @content_type.equal?(UNDEFINED)
					if value = @metadata["content-type"]
						@content_type = Protocol::Media::Type.for(value)
					else
						@content_type = nil
					end
				end
				
				return @content_type
			end
			
			alias media_type content_type
			
			# Decode and memoize the representation value.
			# @returns [Object] The decoded value.
			def value
				if @value.equal?(UNDEFINED)
					@value = @parser.parse(self)
				end
				
				return @value
			end
			
			# Access the decoded representation value.
			def [](...)
				return self.value.[](...)
			end
		end
	end
end
