# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "json"

require_relative "error"

module Protocol
	module Content
		# Parses JSON content with bounded input size and nesting depth.
		class JSONParser
			MEDIA_TYPE = "application/json"
			
			# The encoded JSON document size limit.
			SIZE_LIMIT = 2 * 1024 * 1024
			
			# The JSON document nesting depth limit.
			DEPTH_LIMIT = 32
			
			# Initialize the JSON parser.
			# @parameter size_limit [Integer | Nil] The encoded document size limit.
			# @parameter depth_limit [Integer | Nil] The document nesting depth limit.
			# @parameter options [Hash] Options passed to `JSON.parse`.
			def initialize(size_limit: SIZE_LIMIT, depth_limit: DEPTH_LIMIT, **options)
				@size_limit = size_limit
				options[:max_nesting] = depth_limit || false
				@options = options
			end
			
			# Parse JSON content.
			# @parameter input [Object] The readable input.
			# @returns [Object] The decoded JSON value.
			def parse(input)
				if @size_limit
					buffer = String.new.b
					
					while buffer.bytesize < @size_limit
						chunk = input.read(@size_limit - buffer.bytesize)
						break unless chunk
						break if chunk.empty?
						
						buffer << chunk
					end
					
					if buffer.bytesize == @size_limit && input.read(1)
						raise ContentTooLargeError, "JSON content size exceeded limit of #{@size_limit}!"
					end
				else
					buffer = input.read
				end
				
				return JSON.parse(buffer, **@options)
			rescue JSON::NestingError
				raise ContentTooLargeError
			end
		end
	end
end
