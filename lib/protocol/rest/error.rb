# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Protocol
	module REST
		# A generic REST protocol error.
		class Error < StandardError
		end
		
		# Raised when no parser accepts a representation's media type.
		class UnsupportedMediaTypeError < Error
			# Initialize the error.
			# @parameter media_type [Protocol::Media::Type | Nil] The unsupported media type.
			def initialize(media_type)
				if media_type
					super("Unsupported media type: #{media_type}")
				else
					super("Missing content type!")
				end
				
				@media_type = media_type
			end
			
			# The unsupported media type, if one was provided.
			attr :media_type
		end
	end
end
