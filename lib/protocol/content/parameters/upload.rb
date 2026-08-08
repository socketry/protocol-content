# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/media/type"
require "protocol/media/registry"
require "protocol/multipart/readable"

module Protocol
	module Content
		module Parameters
			# A field-constrained streaming upload.
			class Upload
				include Protocol::Multipart::Readable
				
				GENERIC_MEDIA_TYPE = "application/octet-stream"
				private_constant :GENERIC_MEDIA_TYPE
				
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
					@declared_media_type = nil
					
					if header = delegate.headers["content-type"]
						@declared_media_type = Protocol::Media::Type.parse(header.to_s)
					end
					
					@media_type = @declared_media_type
					
					# Fall back to the submitted filename when the declared type carries no useful classification:
					if !@media_type || @media_type.name == GENERIC_MEDIA_TYPE
						if record = Protocol::Media::Registry.for_path(self.filename)
							if record.type.name != GENERIC_MEDIA_TYPE
								@media_type = record.type
							end
						end
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
				
				# The media type declared by the submitting client, if present.
				attr :declared_media_type
				
				# The declared media type, or the type inferred from the filename when the declaration is absent or generic.
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
