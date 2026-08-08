# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/type"

require_relative "error"

module Protocol
	module Content
		# Selects a content parser according to its media type.
		class Parser
			# Build and freeze a parser.
			# @yields {|parser| ...} The mutable parser being configured.
			# 	@parameter parser [Parser] The parser being configured.
			# @returns [Parser] The configured parser.
			def self.build
				parser = self.new
				yield parser
				return parser.freeze
			end
			
			# Initialize an empty parser.
			def initialize
				@handlers = {}
			end
			
			# Register a handler for a media type.
			# @parameter media_type [String | Protocol::Media::Type] The accepted media type.
			# @parameter handler [#call | Nil] The content handler.
			# @yields {|input, media_type| ...} The content to parse.
			# 	@parameter input [Object] The readable input.
			# 	@parameter media_type [Protocol::Media::Type] The parsed media type.
			# @returns [#call] The registered handler.
			def register(media_type, handler = nil, &block)
				if handler && block
					raise ArgumentError, "Provide either a handler or a block!"
				end
				
				handler ||= block
				
				unless handler&.respond_to?(:call)
					raise ArgumentError, "A content handler must respond to #call!"
				end
				
				media_type = Protocol::Media::Type.for(media_type)
				@handlers[media_type.name] = handler
				return handler
			end
			
			# Parse content using the handler matching its media type.
			# @parameter media_type [String | Protocol::Media::Type | Nil] The media type.
			# @parameter input [Object] The readable input.
			# @yields {...} An optional block forwarded to the selected content handler.
			# @returns [Object] The parsed content value.
			def parse(media_type, input, &block)
				if media_type
					media_type = Protocol::Media::Type.for(media_type)
					
					if handler = @handlers[media_type.name]
						return handler.call(input, media_type, &block)
					end
				end
				
				raise UnsupportedMediaTypeError, media_type
			end
			
			# Freeze the parser and its handler registry.
			# @returns [self] The frozen parser.
			def freeze
				return self if self.frozen?
				
				@handlers.freeze
				super
			end
		end
	end
end
