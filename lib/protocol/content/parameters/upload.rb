# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/type"
require "protocol/multipart/readable"

module Protocol
	module Content
		module Parameters
			# A field-constrained streaming upload.
			class Upload
				include Protocol::Multipart::Readable
				
				# Raised when a streaming upload exceeds its field size limit.
				class LimitError < StandardError
				end
				
				# Initialize a constrained upload.
				# @parameter delegate [Object] The underlying streaming upload.
				# @parameter size_limit [Integer | Nil] The maximum accepted size.
				def initialize(delegate, size_limit: nil)
					@delegate = delegate
					@size_limit = size_limit
					@size = 0
					
					if header = delegate.headers["content-type"]
						@media_type = Protocol::Media::Type.parse(header.to_s)
					end
				end
				
				# The submitted filename.
				def filename
					return @delegate.filename
				end
				
				# The multipart headers associated with this upload.
				def headers
					return @delegate.headers
				end
				
				# The submitted media type, if declared.
				attr :media_type
				
				# The maximum accepted size, if configured.
				attr :size_limit
				
				# The number of bytes consumed through this constrained upload.
				attr :size
				
				# Whether the complete upload has been consumed.
				def ended?
					return @delegate.ended?
				end
				
				# Iterate over the upload while enforcing its field size limit.
				# @parameter chunk_size [Integer] The maximum chunk size.
				# @yields {|chunk| ...} Each upload chunk.
				# @returns [self] The upload.
				# @raises [LimitError] If the upload exceeds its field size limit.
				def each(chunk_size = 8192)
					return to_enum(:each, chunk_size) unless block_given?
					
					@delegate.each(chunk_size) do |chunk|
						@size += chunk.bytesize
						
						if @size_limit && @size > @size_limit
							raise LimitError, "Upload size exceeded field limit of #{@size_limit}!"
						end
						
						yield chunk
					end
					
					return self
				end
				
				# Consume any unread upload content while enforcing the field size limit.
				# @returns [Nil] The upload content is discarded.
				def discard
					each {|_chunk|}
					return nil
				end
			end
		end
	end
end
