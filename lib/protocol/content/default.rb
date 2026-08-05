# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../content"
require_relative "json_parser"

require "protocol/url/form_data/parser"
require "protocol/multipart/form_data/parser"

module Protocol
	module Content
		class Parser
			DEFAULT = build do |parser|
				json_parser = JSONParser.new
				parser.register(JSONParser::MEDIA_TYPE) do |input|
					json_parser.parse(input)
				end
				
				url_encoded_form_parser = Protocol::URL::FormData::Parser.new
				parser.register(Protocol::URL::FormData::Parser::MEDIA_TYPE) do |input, _media_type, &block|
					url_encoded_form_parser.parse(input, &block)
				rescue Protocol::URL::LimitError
					raise ContentTooLargeError
				end
				
				multipart_form_parser = Protocol::Multipart::FormData::Parser.new
				parser.register(Protocol::Multipart::FormData::Parser::MEDIA_TYPE) do |input, media_type, &block|
					if boundary = media_type.parameters["boundary"]
						multipart_form_parser.parse(input, boundary: boundary, &block)
					else
						raise ArgumentError, "Multipart media type is missing a boundary!"
					end
				rescue Protocol::Multipart::LimitError, Protocol::URL::LimitError
					raise ContentTooLargeError
				end
			end
			
			# The default parser for common media types.
			# @returns [Parser] The frozen default parser.
			def self.default
				return DEFAULT
			end
		end
	end
end
