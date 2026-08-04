# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module Content
		# A generic content error.
		class Error < StandardError
		end
		
		# Raised when content cannot be parsed.
		class ParseError < Error
		end
		
		# Raised when content exceeds a configured parser limit.
		class ContentTooLargeError < ParseError
		end
		
		# Raised when no parser accepts a media type.
		class UnsupportedMediaTypeError < Error
			# Initialize the error.
			# @parameter media_type [Protocol::Media::Type | Nil] The unsupported media type.
			def initialize(media_type)
				if media_type
					super("Unsupported media type: #{media_type}")
				else
					super("Missing media type!")
				end
				
				@media_type = media_type
			end
			
			# The unsupported media type, if one was provided.
			attr :media_type
		end
	end
end
