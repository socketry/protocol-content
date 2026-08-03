# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/map"

require_relative "../error"

module Protocol
	module REST
		class Representation
			# Selects a representation parser according to its media type.
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
				# @parameter handler [#call | Nil] The representation handler.
				# @yields {|representation| ...} The representation to parse.
				# 	@parameter representation [Representation] The encoded representation.
				# @returns [#call] The registered handler.
				def register(media_range, handler = nil, &block)
					if handler && block
						raise ArgumentError, "Provide either a handler or a block!"
					end
					
					handler ||= block
					
					unless handler&.respond_to?(:call)
						raise ArgumentError, "A representation handler must respond to #call!"
					end
					
					@handlers[media_range] = handler
					return handler
				end
				
				# Parse a representation using the handler matching its media type.
				# @parameter representation [Representation] The encoded representation.
				# @returns [Object] The parsed representation value.
				def parse(representation)
					media_type = representation.content_type
					
					if media_type && handler = @handlers[media_type]
						return handler.call(representation)
					end
					
					raise UnsupportedMediaTypeError, media_type
				end
				
				# Freeze the parser and its handler registry.
				# @returns [self] The frozen parser.
				def freeze
					@handlers.freeze
					super
				end
			end
		end
	end
end
