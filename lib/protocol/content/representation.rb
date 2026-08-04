# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/type"

require_relative "parser"

module Protocol
	module Content
		# A representation consists of encoded data and metadata describing that data.
		class Representation
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
				return self.new(message.headers, message.body, parser: parser)
			end
			
			# Initialize a representation.
			# @parameter metadata [Object] The representation metadata.
			# @parameter body [Object | Nil] The encoded representation data.
			# @parameter parser [Parser] The parser used to decode the representation.
			def initialize(metadata, body, parser: self.class.parser)
				@metadata = metadata
				@body = body
				@content_type = Protocol::Media::Type.for(metadata["content-type"])
				@parser = parser
				@value = nil
				@parsed = false
			end
			
			# Metadata describing the representation.
			attr :metadata
			
			# The encoded representation body.
			attr :body
			
			# The parser used to decode the representation.
			attr :parser
			
			# The representation media type described by its metadata.
			# @returns [Protocol::Media::Type | Nil] The content type, if present.
			attr :content_type
			
			alias media_type content_type
			
			# Decode and memoize the representation value.
			# @returns [Object] The decoded value.
			def value
				unless @parsed
					@value = @parser.parse(self)
					@parsed = true
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
