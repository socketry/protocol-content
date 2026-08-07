# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/map"
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
				@handlers = Protocol::Media::Map.new
			end
			
			# Register a handler for a media type or range.
			# @parameter media_range [String | Protocol::Media::Range] The accepted media type or range.
			# @parameter handler [#call | Nil] The content handler.
			# @yields {|input, media_type| ...} The content to parse.
			# 	@parameter input [Object] The readable input.
			# 	@parameter media_type [Protocol::Media::Type] The parsed media type.
			# @returns [#call] The registered handler.
			def register(media_range, handler = nil, &block)
				if handler && block
					raise ArgumentError, "Provide either a handler or a block!"
				end
				
				handler ||= block
				
				unless handler&.respond_to?(:call)
					raise ArgumentError, "A content handler must respond to #call!"
				end
				
				@handlers[media_range] = handler
				return handler
			end
			
			# Parse content using the handler matching its media type.
			# @parameter media_type [String | Protocol::Media::Type | Nil] The media type.
			# @parameter input [Object] The readable input.
			# @yields {...} An optional block forwarded to the selected content handler.
			# @returns [Object] The parsed content value.
			def parse(media_type, input, &block)
				media_type = Protocol::Media::Type.for(media_type)
				
				if media_type && handler = @handlers[media_type]
					return handler.call(input, media_type, &block)
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
