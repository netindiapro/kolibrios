;;================================================================================================;;
;;//// tiff.asm //// (c) dunkaist, 2011-2013 /////////////////////////////////////////////////////;;
;;================================================================================================;;
;;                                                                                                ;;
;; This file is part of Common development libraries (Libs-Dev).                                  ;;
;;                                                                                                ;;
;; Libs-Dev is free software: you can redistribute it and/or modify it under the terms of the GNU ;;
;; Lesser General Public License as published by the Free Software Foundation, either version 2.1 ;;
;; of the License, or (at your option) any later version.                                         ;;
;;                                                                                                ;;
;; Libs-Dev is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without  ;;
;; even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU  ;;
;; Lesser General Public License for more details.                                                ;;
;;                                                                                                ;;
;; You should have received a copy of the GNU Lesser General Public License along with Libs-Dev.  ;;
;; If not, see <http://www.gnu.org/licenses/>.                                                    ;;
;;                                                                                                ;;
;;================================================================================================;;

include 'tiff.inc'

;;================================================================================================;;
proc img.is.tiff _data, _length ;/////////////////////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Determine if raw data could be decoded (is in tiff format)                                     ;;
;;------------------------------------------------------------------------------------------------;;
;> _data = raw data as read from file/stream                                                      ;;
;> _length = data length                                                                          ;;
;;------------------------------------------------------------------------------------------------;;
;< eax = false / true                                                                             ;;
;;================================================================================================;;

	push	esi

	mov	esi, [_data]
	lodsw
	cmp	ax, word 'II'
	je	.little_endian
	cmp	ax, word 'MM'
	je	.big_endian
	jmp	.is_not_tiff

  .little_endian:
	lodsw
	cmp	ax, 0x002A
	je	.is_tiff
	jmp	.is_not_tiff

  .big_endian:
	lodsw
	cmp	ax, 0x2A00
	je	.is_tiff

  .is_not_tiff:
	pop	esi
	xor	eax, eax
	ret

  .is_tiff:
	pop	esi
	xor	eax, eax
	inc	eax
	ret
endp

;;================================================================================================;;
proc img.decode.tiff _data, _length, _options ;///////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Decode data into image if it contains correctly formed raw data in tiff format                 ;;
;;------------------------------------------------------------------------------------------------;;
;> _data = raw data as read from file/stream                                                      ;;
;> _length = data length                                                                          ;;
;;------------------------------------------------------------------------------------------------;;
;< eax = 0 (error) or pointer to image                                                            ;;
;;================================================================================================;;
locals
	_endianness		rd 1		; 0 stands for LE, otherwise BE
	retvalue		rd 1		; 0 (error) or pointer to image
endl

	push	ebx esi edi

	mov	esi, [_data]
	lodsw
	mov	[_endianness], 0
	cmp	ax, word 'II'
	seta	byte[_endianness]

	lodsw_
	lodsd_
    @@:
;	push	eax
	stdcall	tiff._.parse_IFD, [_data], eax, [_endianness]
;	pop	esi
;	mov	ebx, eax
;	mov	[retvalue], eax
;	xor	eax, eax
;	lodsw_
;	shl	eax, 2
;	lea	eax, [eax*3]
;	add	esi, eax
;	lodsd_
;	test	eax, eax
;	jnz	@b
;  .quit:
;	mov	eax, [retvalue]
	pop	edi esi ebx
	ret
endp


;;================================================================================================;;
proc img.encode.tiff _img, _p_length, _options ;//////////////////////////////////////////////////;;
;;------------------------------------------------------------------------------------------------;;
;? Encode image into raw data in tiff format                                                      ;;
;;------------------------------------------------------------------------------------------------;;
;> _img = pointer to image                                                                        ;;
;;------------------------------------------------------------------------------------------------;;
;< eax = 0 (error) or pointer to encoded data                                                     ;;
;< _p_length = encoded data length                                                                ;;
;;================================================================================================;;
	xor	eax, eax
	ret
endp


;;================================================================================================;;
;;////////////////////////////////////////////////////////////////////////////////////////////////;;
;;================================================================================================;;
;! Below are private procs you should never call directly from your code                          ;;
;;================================================================================================;;
;;////////////////////////////////////////////////////////////////////////////////////////////////;;
;;================================================================================================;;
proc tiff._.parse_IFD _data, _IFD, _endianness
locals
	extended		rd	1
	retvalue		rd	1
	decompress		rd	1
endl
	push	ebx edx edi
	mov	[retvalue], 0

	invoke	mem.alloc, sizeof.tiff_extra
	test	eax, eax
	jz	.quit
	mov	[extended], eax
	mov	ebx, eax
	mov	edi, eax
	mov	ecx, sizeof.tiff_extra/4
	xor	eax, eax
	rep	stosd

	mov	esi, [_IFD]
	add	esi, [_data]
	lodsw_
	movzx	ecx, ax
    @@:
	push	ecx
	stdcall	tiff._.parse_IFDE, [_data], [_endianness]
	pop	ecx
	dec	ecx
	jnz	@b

	call	tiff._.define_image_type

	stdcall	img.create, [ebx + tiff_extra.image_width], [ebx + tiff_extra.image_height], eax
	test	eax, eax
	jz	.quit
	mov	[retvalue], eax
	mov	edx, eax
	mov	[edx + Image.Extended], ebx

	cmp	[ebx+tiff_extra.compression], TIFF.COMPRESSION.UNCOMPRESSED
	jne	@f
	mov	[decompress], tiff._.decompress.uncompressed
	jmp	.decompressor_defined
    @@:
	cmp	[ebx + tiff_extra.compression], TIFF.COMPRESSION.PACKBITS
	jne	@f
	mov	[decompress], tiff._.decompress.packbits
	jmp	.decompressor_defined
    @@:
	cmp	[ebx + tiff_extra.compression], TIFF.COMPRESSION.LZW
	jne	@f
	mov	[decompress], tiff._.decompress.lzw
	jmp	.decompressor_defined
    @@:
	cmp	[ebx + tiff_extra.compression], TIFF.COMPRESSION.CCITT1D
	jne	@f
	mov	[decompress], tiff._.decompress.ccitt1d
	jmp	.decompressor_defined
    @@:

	mov	[decompress], 0
	jmp	.quit
  .decompressor_defined:

	push	esi		; fixme!!

	mov	ecx, [edx + Image.Type]
        cmp     ecx, Image.bpp8i
        je	.bpp8i
        cmp     ecx, Image.bpp24
	je	.bpp24
        cmp     ecx, Image.bpp32
	je	.bpp32
        cmp     ecx, Image.bpp16
	je	.bpp16
        cmp     ecx, Image.bpp1
	je	.bpp1
        cmp     ecx, Image.bpp8g
	je	.bpp8g
        cmp     ecx, Image.bpp8a
	je	.bpp8a
        cmp     ecx, Image.bpp2i
	je	.bpp2i
        cmp     ecx, Image.bpp4i
	je	.bpp4i
        jmp     .quit
;error report!!

  .bpp1:
  .bpp1.palette:
	mov	edi, [edx+Image.Palette]
	cmp	[ebx + tiff_extra.photometric], TIFF.PHOTOMETRIC.BLACK_IS_ZERO
	jne	.bpp1.white_is_zero
  .bpp1.black_is_zero:
	mov	[edi], dword 0xff000000
	mov	[edi + 4], dword 0xffffffff
	jmp	.common
  .bpp1.white_is_zero:
	mov	[edi], dword 0xffffffff
	mov	[edi + 4], dword 0xff000000
	jmp	.common

  .bpp2i:
        stdcall tiff._.get_palette, 1 SHL 2, [_endianness]
	jmp	.common

  .bpp4i:
        stdcall tiff._.get_palette, 1 SHL 4, [_endianness]
	jmp	.common

  .bpp8i:
        stdcall tiff._.get_palette, 1 SHL 8, [_endianness]
	jmp	.common
  .bpp8g:
	jmp	.common

  .bpp8a:
	jmp	.common

  .bpp16:
	jmp	.common

  .bpp24:
	jmp	.common

  .bpp32:
	jmp	.common


  .common:
	mov	edi, [edx+Image.Data]
	mov	esi, [ebx+tiff_extra.strip_offsets]
	mov	edx, [ebx+tiff_extra.strip_byte_counts]


	cmp	[ebx + tiff_extra.strip_offsets_length], TIFF.IFDE_TYPE_LENGTH.SHORT
	jne	.l_x
	cmp	[ebx + tiff_extra.strip_byte_counts_length], TIFF.IFDE_TYPE_LENGTH.SHORT
	jne	.s_l
	jmp	.s_s
  .l_x:	cmp	[ebx + tiff_extra.strip_byte_counts_length], TIFF.IFDE_TYPE_LENGTH.SHORT
	jne	.l_l
	jmp	.l_s

  .s_s:
	xor	eax, eax
	lodsw_
	push	esi
	mov	esi, eax
	add	esi, [_data]
	xor	ecx, ecx
	mov	cx, word[edx]
	test	[_endianness], 1
	jz	@f
	xchg	cl, ch
    @@:
	add	edx, 2
	stdcall	[decompress], [retvalue]
	pop	esi
	dec	[ebx + tiff_extra.offsets_number]
	jnz	.s_s
	jmp	.decoded

  .s_l:
	xor	eax, eax
	lodsw_
	push	esi
	mov	esi, eax
	add	esi, [_data]
	mov	ecx, [edx]
	test	[_endianness], 1
	jz	@f
	bswap	ecx
    @@:
	add	edx, 4
	stdcall	[decompress], [retvalue]
	pop	esi
	dec	[ebx + tiff_extra.offsets_number]
	jnz	.s_l
	jmp	.decoded

  .l_s:
	lodsd_
	push	esi
	mov	esi, eax
	add	esi, [_data]
	xor	ecx, ecx
	mov	cx, word[edx]
	test	[_endianness], 1
	jz	@f
	xchg	cl, ch
    @@:
	add	edx, 2
	stdcall	[decompress], [retvalue]
	pop	esi
	dec	[ebx + tiff_extra.offsets_number]
	jnz	.l_s
	jmp	.decoded

  .l_l:
	lodsd_
	push	esi
	mov	esi, eax
	add	esi, [_data]
	mov	ecx, [edx]
	test	[_endianness], 1
	jz	@f
	bswap	ecx
    @@:
	add	edx, 4
	stdcall	[decompress], [retvalue]
	pop	esi
	dec	[ebx + tiff_extra.offsets_number]
	jnz	.l_l
	jmp	.decoded


  .decoded:
        cmp     [ebx + tiff_extra.planar_configuration], TIFF.PLANAR.PLANAR
        jne     .post.rgb_bgr
        stdcall tiff._.planar_to_separate, [retvalue]
  .post.rgb_bgr:
	cmp	[ebx + tiff_extra.samples_per_pixel], 3
	jne	.post.rgba_bgra
	mov	eax, [retvalue]
	mov	esi, [eax + Image.Data]
	mov	edi, [eax + Image.Data]
	mov	ecx, [eax + Image.Width]
	imul	ecx, [eax + Image.Height]
    @@:
	lodsw
	movsb
	mov	byte[esi - 1], al
	add	edi, 2
	dec	ecx
	jnz	@b
	jmp	.post.predictor

  .post.rgba_bgra:
	cmp	[ebx + tiff_extra.samples_per_pixel], 4
	jne	.post.bpp8a_to_bpp8g
	mov	eax, [retvalue]
	mov	esi, [eax + Image.Data]
	mov	edi, [eax + Image.Data]
	mov	ecx, [eax + Image.Width]
	imul	ecx, [eax + Image.Height]
    @@:
	lodsw
	movsb
	mov	byte[esi - 1], al
	add	edi, 3
	add	esi, 1
	dec	ecx
	jnz	@b
	jmp	.post.predictor

  .post.bpp8a_to_bpp8g:
	mov	eax, [retvalue]
	cmp	[eax + Image.Type], Image.bpp8a
	jne	.post.predictor
	mov	ebx, [retvalue]
	stdcall	tiff._.pack_8a, ebx
	mov	[ebx + Image.Type], Image.bpp8g

  .post.predictor:
	cmp	[ebx + tiff_extra.predictor], 2		; Horizontal differencing
	jne	.post.end
	cmp	[ebx + tiff_extra.image_width], 1
	je	.post.end
	push	ebx
	mov	edi, [ebx + tiff_extra.samples_per_pixel]
	mov	edx, edi
	mov	ebx, [retvalue]
  .post.predictor.plane:
	mov	esi, [ebx + Image.Data]
	sub	esi, 1
	add	esi, edx
	mov	ecx, [ebx + Image.Height]
  .post.predictor.line:
	push	ecx
	mov	ecx, [ebx + Image.Width]
	sub	ecx, 1
	mov	ah, byte[esi]
	add	esi, edi
    @@:
	mov	al, byte[esi]
	add	al, ah
	mov	byte[esi], al
	add	esi, edi
	shl	eax, 8
	dec	ecx
	jnz	@b
	pop	ecx
	dec	ecx
	jnz	.post.predictor.line
	dec	edx
	jnz	.post.predictor.plane
	pop	ebx

  .post.end:

  .pop_quit:
	pop	esi
  .quit:
	pop	edi edx ebx
	mov	eax, [retvalue]
	ret
endp

proc tiff._.parse_IFDE _data, _endianness

	push	ebx edx edi

	lodsw_
	mov	edx, tiff.IFDE_tag_table.begin
	mov	ecx, (tiff.IFDE_tag_table.end-tiff.IFDE_tag_table.begin)/8
  .tag:
	cmp	ax, word[edx]
	jne	@f
	lodsw_
	jmp	dword[edx + 4]
    @@:
	add	edx, 8
	dec	ecx
	jnz	.tag
  .tag_default:						; unknown/unsupported/unimportant
	lodsw
	lodsd
	lodsd
	jmp	.quit					; just skip it

  .tag_100:						; ImageWidth
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.image_width], eax
	lodsw
	jmp	.quit
    @@:
	cmp	ax, TIFF.IFDE_TYPE.LONG
	jne	@f
	lodsd
	lodsd_
	mov	[ebx + tiff_extra.image_width], eax
	jmp	.quit
    @@:
	jmp	.quit

  .tag_101:						; ImageHeight
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.image_height], eax
	lodsw
	jmp	.quit
    @@:
	cmp	ax, TIFF.IFDE_TYPE.LONG
	jne	@f
	lodsd
	lodsd_
	mov	[ebx + tiff_extra.image_height], eax
	jmp	.quit
    @@:
	jmp	.quit

  .tag_102:						; BitsPerSample
	lodsd_
	imul	eax, TIFF.IFDE_TYPE_LENGTH.SHORT
	cmp	eax, 4
	ja	@f
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.bits_per_sample], eax
	lodsw
	jmp	.quit
    @@:
	lodsd_
	add	eax, [_data]
	push	esi
	mov	esi, eax
	xor	eax, eax
	lodsw_
	pop	esi
	mov	[ebx + tiff_extra.bits_per_sample], eax
	jmp	.quit

  .tag_103:						; Compression
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.compression], eax
	lodsw
	jmp	.quit
    @@:
	jmp	.quit

  .tag_106:						; PhotometricInterpretation
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.photometric], eax
	lodsw
	jmp	.quit
    @@:

	jmp	.quit

  .tag_111:						; StripOffsets
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	mov	[ebx + tiff_extra.strip_offsets_length], TIFF.IFDE_TYPE_LENGTH.SHORT
	jmp	.tag_111.common
    @@:
	mov	[ebx + tiff_extra.strip_offsets_length], TIFF.IFDE_TYPE_LENGTH.LONG
  .tag_111.common:
	lodsd_
	mov	[ebx + tiff_extra.offsets_number], eax
	imul	eax, [ebx+tiff_extra.strip_offsets_length]
	cmp	eax, 4
	ja	@f
	mov	[ebx + tiff_extra.strip_offsets], esi
	lodsd
	jmp	.quit
    @@:
	lodsd_
	add	eax, [_data]
	mov	[ebx + tiff_extra.strip_offsets], eax
	jmp	.quit

  .tag_115:						; SamplesPerPixel
	lodsd_
	imul	eax, TIFF.IFDE_TYPE_LENGTH.SHORT
	cmp	eax, 4
	ja	@f
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.samples_per_pixel], eax
	lodsw
	jmp	.quit
    @@:
	lodsd_
	add	eax, [_data]
	movzx	eax, word[eax]
	jmp	.quit

  .tag_116:						; RowsPerStrip
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.rows_per_strip], eax
	lodsw
	jmp	.quit
    @@:
	lodsd
	lodsd_
	mov	[ebx + tiff_extra.rows_per_strip], eax
	jmp	.quit

  .tag_117:						; StripByteCounts
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	mov	[ebx + tiff_extra.strip_byte_counts_length], TIFF.IFDE_TYPE_LENGTH.SHORT
	jmp	.tag_117.common
    @@:
	mov	[ebx + tiff_extra.strip_byte_counts_length], TIFF.IFDE_TYPE_LENGTH.LONG
  .tag_117.common:
	lodsd_
	imul	eax, [ebx + tiff_extra.strip_byte_counts_length]
	cmp	eax, 4
	ja	@f
	mov	[ebx + tiff_extra.strip_byte_counts], esi
	lodsd
	jmp	.quit
    @@:
	lodsd_
	add	eax, [_data]
	mov	[ebx + tiff_extra.strip_byte_counts], eax
	jmp	.quit

  .tag_11c:						; Planar configuration
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.planar_configuration], eax
	lodsw
    @@:
	jmp	.quit


  .tag_13d:						; Predictor
	cmp	ax, TIFF.IFDE_TYPE.SHORT
	jne	@f
	lodsd
	xor	eax, eax
	lodsw_
	mov	[ebx + tiff_extra.predictor], eax
	lodsw
    @@:
	jmp	.quit

  .tag_140:						; ColorMap
	lodsd
	lodsd_
	add	eax, [_data]
	mov	[ebx + tiff_extra.palette], eax
	jmp	.quit
  .tag_152:						; ExtraSamples
	mov	[ebx + tiff_extra.extra_samples], esi
	mov	ecx, [ebx + tiff_extra.extra_samples_number]
	rep	lodsw	; ignored
	jmp	.quit

  .quit:
	pop	edi edx ebx
	ret
endp


proc tiff._.define_image_type

	xor	eax, eax

	cmp	[ebx + tiff_extra.photometric], TIFF.PHOTOMETRIC.RGB
	jne	.palette_bilevel_grayscale
	mov	eax, -3
	add	eax, [ebx + tiff_extra.samples_per_pixel]
	mov	[ebx + tiff_extra.extra_samples_number], eax
	dec	eax
	jns	@f
	mov	eax, Image.bpp24
	jmp	.quit
    @@:
	dec	eax
	jns	@f
	mov	eax, Image.bpp32
;	mov	[ebx + tiff_extra.extra_samples_number], 0
	jmp	.quit
    @@:
  .palette_bilevel_grayscale:
	cmp	[ebx + tiff_extra.palette], 0
	je	.bilevel_grayscale
	cmp	[ebx + tiff_extra.bits_per_sample], 2
	jg	@f
	mov	eax, Image.bpp2i
	jmp	.quit
    @@:
	cmp	[ebx + tiff_extra.bits_per_sample], 4
	jg	@f
	mov	eax, Image.bpp4i
	jmp	.quit
    @@:
	cmp	[ebx + tiff_extra.bits_per_sample], 8
	jne	@f
	mov	eax, Image.bpp8i
	jmp	.quit
    @@: 
	jmp	.quit
  .bilevel_grayscale:
	cmp	[ebx + tiff_extra.bits_per_sample], 1
	jg	.grayscale
	mov	eax, Image.bpp1
	jmp	.quit
  .grayscale:
	cmp	[ebx + tiff_extra.bits_per_sample], 8
        jne     .quit
	cmp	[ebx + tiff_extra.samples_per_pixel], 1
        jne     @f
	mov	eax, Image.bpp8g
	jmp	.quit
    @@:
	mov	eax, Image.bpp8a
	jmp	.quit
  .quit:
	ret
endp


proc tiff._.decompress.uncompressed _image

	rep	movsb
	ret
endp


proc tiff._.decompress.packbits _image

	push	edx

	mov	edx, ecx

  .decode:
	lodsb
	dec	edx
	cmp	al, 0x80
	jb	.different
	jg	.identical
	test	edx, edx
	jz	.quit
	jmp	.decode

  .identical:
	neg	al
	inc	al
	movzx	ecx, al
	dec	edx
	lodsb
	rep	stosb
	test	edx, edx
	jnz	.decode
	jmp	.quit

  .different:
	movzx	ecx, al
	inc	ecx
	sub	edx, ecx
	rep	movsb
	test	edx, edx
	jnz	.decode

  .quit:
	pop	edx
	ret
endp


proc	tiff._.decompress.ccitt1d _image
locals
	current_tree		rd	1
	old_tree		rd	1
	width			rd	1
	height			rd	1
	width_left		rd	1
	is_makeup		rd	1
endl
	push	ebx ecx edx esi
	mov	[is_makeup], 0

	mov	ebx, [_image]
	push	[ebx + Image.Height]
	pop	[height]
	push	[ebx + Image.Width]
	pop	[width]

	mov	edx, esi
  .next_scanline:
	push	[width]
	pop	[width_left]
	dec	[height]
	js	.error
	mov	[current_tree], tiff._.huffman_tree_white.begin
	mov	[old_tree], tiff._.huffman_tree_black.begin
	mov	ebx, 0
	mov	ecx, 8
  .next_run:
	mov	esi, [current_tree]
  .branch:
	lodsd
	btr	eax, 31
	jnc	.not_a_leaf
	cmp	eax, 63
	seta	byte[is_makeup]
	ja	@f
	push	[current_tree]
	push	[old_tree]
	pop	[current_tree]
	pop	[old_tree]
    @@:
	stdcall	tiff._.write_run, [width_left], [current_tree]
	mov	[width_left], eax
	test	byte[is_makeup], 0x01
	jnz	.next_run
	test	eax, eax
	jnz	.next_run
	jmp	.next_scanline
  .not_a_leaf:
	test	bh, bh
	jnz	@f
	mov	bl, byte[edx]
	inc	edx
	mov	bh, 8
    @@:
	test	al, 0x02
	jz	.not_a_corner
	dec	bh
	sal	bl, 1
	lahf
	and	ah, 0x03
	cmp	al, ah
	jne	.error
	mov	esi, [esi]
	jmp	.branch
  .not_a_corner:
	lodsd
	dec	bh
	sal	bl, 1
	jc	.branch
	mov	esi, eax
	jmp	.branch
  .error:
  .quit:
	pop	esi edx ecx ebx
	ret
endp

struct lzw_ctx
	bits_left	 dd ?	; in current byte (pointed to by [esi])
	cur_shift	 dd ?	; 9 -- 12
	shift_counter	 dd ?	; how many shifts of current length remained
	table		 dd ?
	last_table_entry dd ?	; zero based
	next_table_entry dd ?	; where to place new entry
	strip_len	 dd ?
	old_code	 dd ?
ends

proc tiff._.lzw_get_code
	mov	edx, [ebx+lzw_ctx.cur_shift]
	xor	eax, eax
	lodsb
	mov	ecx, [ebx+lzw_ctx.bits_left]
	mov	ch, cl
	neg	cl
	add	cl, 8
	shl	al, cl
	mov	cl, ch
	shl	eax, cl
	sub	edx, [ebx+lzw_ctx.bits_left]
	; second_byte
	cmp	edx, 8
	je	.enough_zero
	jb	.enough_nonzero
	sub	edx, 8
	lodsb
	shl	eax, 8
	jmp	.enough_nonzero
  .enough_zero:
	mov	[ebx+lzw_ctx.bits_left], 8
	lodsb
	jmp	.code_done
  .enough_nonzero:
	mov	al, byte[esi]
	neg	edx
	add	edx, 8
	mov	ecx, edx
	mov	[ebx+lzw_ctx.bits_left], edx
	shr	eax, cl
  .code_done:
	dec	[ebx+lzw_ctx.shift_counter]
	jnz	@f
	mov	ecx, [ebx+lzw_ctx.cur_shift]
	add	[ebx+lzw_ctx.cur_shift], 1
	mov	edx, 1
	shl	edx, cl
	mov	[ebx+lzw_ctx.shift_counter], edx
    @@:
	ret
endp

proc tiff._.add_string_to_table uses esi
	mov	esi, [ebx+lzw_ctx.table]
	lea	esi, [esi + eax*8 + 256]
	mov	ecx, dword[esi+4]

	mov	edx, [ebx+lzw_ctx.next_table_entry]
	mov	[edx], edi
	lea	eax, [ecx + 1]
	mov	[edx + 4], eax
	add	[ebx+lzw_ctx.next_table_entry], 8
	add	[ebx+lzw_ctx.last_table_entry], 1

	mov	esi, [esi]
	cmp	ecx, [ebx+lzw_ctx.strip_len]
	cmovg	ecx, [ebx+lzw_ctx.strip_len]
	sub	[ebx+lzw_ctx.strip_len], ecx
	rep	movsb
	ret
endp

proc tiff._.init_code_table
	cmp	[ebx+lzw_ctx.table], 0
	jne	@f
	invoke	mem.alloc, 256 + 63488	; 256 + (2^8 + 2^9 + 2^10 + 2^11 + 2^12)*(4+4)
	test	eax, eax
	jz	.quit
	mov	[ebx+lzw_ctx.table], eax
    @@:
	mov	eax, [ebx+lzw_ctx.table]
	mov	[ebx+lzw_ctx.next_table_entry], eax
	add	[ebx+lzw_ctx.next_table_entry], 256 + (256*8) + 2*8
	mov	[ebx+lzw_ctx.cur_shift], 9
	mov	[ebx+lzw_ctx.shift_counter], 256-2	; clear code, end of information
	mov	[ebx+lzw_ctx.last_table_entry], 257	; 0--255, clear, eoi

	push	edi
	mov	ecx, 256
	mov	edi, [ebx+lzw_ctx.table]
	mov	edx, edi
	add	edi, 256
	mov	eax, 0
    @@:
	mov	byte[edx], al
	mov	[edi], edx
	add	edi, 4
	add	edx, 1
	add	eax, 1
	mov	[edi], dword 1
	add	edi, 4
	dec	ecx
	jnz	@b
	pop	edi
.quit:
	ret
endp

proc tiff._.decompress.lzw _image
locals
	ctx			lzw_ctx
endl
	push	ebx ecx edx esi
	mov	ecx, [ebx+tiff_extra.rows_per_strip]
	mov	ebx, [_image]
	mov	eax, [ebx+Image.Width]
	call	img._.get_scanline_len
	imul	eax, ecx

	lea	ebx, [ctx]
	mov	[ctx.strip_len], eax
	mov	[ctx.table], 0
	mov	[ctx.bits_left], 8
	mov	[ctx.cur_shift], 9

  .begin:
	cmp	[ctx.strip_len], 0
	jle	.quit
	stdcall	tiff._.lzw_get_code
	cmp	eax, 0x101	; end of information
	je	.quit
	cmp	eax, 0x100	; clear code
	jne	.no_clear_code
	call	tiff._.init_code_table

	; getnextcode
	call	tiff._.lzw_get_code
	mov	[ctx.old_code], eax
	cmp	eax, 0x101	; end of information
	je	.quit
	call	tiff._.add_string_to_table
	jmp	.begin
  .no_clear_code:
	cmp	eax, [ctx.last_table_entry]
	ja	.not_in_table
	mov	[ctx.old_code], eax
	call	tiff._.add_string_to_table
	jmp	.begin
  .not_in_table:
	xchg	eax, [ctx.old_code]
	call	tiff._.add_string_to_table
	cmp	[ctx.strip_len], 0
	jle	@f
	dec	[ctx.strip_len]
	mov	byte[edi], al
	add	edi, 1
    @@:
	jmp	.begin
  .quit:
	cmp	[ctx.table], 0
	je	@f
	invoke	mem.free, [ctx.table]
    @@:
	pop	esi edx ecx ebx
	ret
endp


proc	tiff._.write_run _width_left, _current_tree

	push	ebx

	test	eax, eax
	jz	.done
	sub	[_width_left], eax
	js	.error
	cmp	esi, tiff._.huffman_tree_black.begin
	seta	bh

	cmp	ecx, eax
	ja	.one_byte
  .many_bytes:
	mov	bl, [edi]
    @@:
	shl	bl, 1
	or	bl, bh
	dec	eax
	dec	ecx
	jnz	@b
	mov	[edi], bl
	inc	edi
	mov	ecx, eax
	and	eax, 0x07
	shr	ecx, 3

	push	eax
	xor	eax, eax
	test	bh, bh
	jz	@f
	dec	al
    @@:
	rep	stosb
	pop	eax

	mov	ecx, 8
	test	eax, eax
	jz	.done

  .one_byte:
	mov	bl, [edi]
    @@:
	shl	bl, 1
	or	bl, bh
	dec	ecx
	dec	eax
	jnz	@b
	mov	byte[edi], bl

	cmp	[_width_left], 0
	jne	.done
	mov	bl, [edi]
	shl	bl, cl
	mov	byte[edi], bl
	inc	edi
  .done:
	mov	eax, [_width_left]
	jmp	.quit
  .error:
  .quit:
	pop	ebx
	ret
endp


proc	tiff._.get_word _endianness

	lodsw
	test	[_endianness], 1
	jnz	@f
	ret
    @@:
	xchg	al, ah
	ret
endp


proc	tiff._.get_dword _endianness

	lodsd
	test	[_endianness], 1
	jnz	@f
	ret
    @@:
	bswap	eax
	ret

	ret
endp


proc	tiff._.pack_8a _img
	mov	ebx, [_img]
	mov	esi, [ebx + Image.Data]
	mov	edi, esi
	mov	ecx, [ebx + Image.Width]
	imul	ecx, [ebx + Image.Height]
    @@:
	lodsw
	stosb
	dec	ecx
	jnz	@b
	ret
endp


proc tiff._.planar_to_separate _img
locals
        pixels          rd 1
        tmp_image       rd 1
        channels        rd 1
        channel_padding rd 1
endl
        pushad
        mov     ebx, [_img]
        mov     ecx, [ebx + Image.Width]
        imul    ecx, [ebx + Image.Height]
        mov     [pixels], ecx
        cmp     [ebx + Image.Type], Image.bpp24
        je      .bpp24
        cmp     [ebx + Image.Type], Image.bpp32
        je      .bpp32
;        cmp     [ebx + Image.Type], Image.bpp4
;        je      .bpp4
        jmp     .quit
  .bpp24:
        mov     [channels], 3
        mov     [channel_padding], 2
        lea     eax, [ecx*3]
        jmp     .proceed
  .bpp32:
        mov     [channels], 4
        mov     [channel_padding], 3
        shl     eax, 2
        jmp     .proceed
  .bpp4:
        mov     [channels], 3
        mov     [channel_padding], 2
        shr     eax, 1
        jmp     .proceed
  .proceed:
        invoke  mem.alloc, eax
        test    eax, eax
        jz      .quit
        mov     [tmp_image], eax
  .channel:
        mov     esi, [ebx + Image.Data]
        mov     edi, [tmp_image]
        mov     ecx, [pixels]
        mov     eax, [channel_padding]
        inc     eax
        sub     eax, [channels]
        add     edi, eax
        mov     eax, [channels]
        dec     eax
        imul    eax, [pixels]
        add     esi, eax
    @@:
        lodsb
        stosb
        add     edi, [channel_padding]
        dec     ecx
        jnz     @b
        dec     [channels]
        jnz     .channel

  .quit:
        mov     eax, [tmp_image]
        xchg    [ebx + Image.Data], eax
        invoke  mem.free, eax
        popad
        ret
endp


proc tiff._.get_palette _num_colors, _endianness
	mov	esi, [ebx + tiff_extra.palette]
        push    ebx
	mov	ebx, 2
  .bpp2.channel:
	mov	edi, ebx
	add	edi, [edx + Image.Palette]
	mov	ecx, [_num_colors]
    @@:
        lodsw_
        shr     eax, 8
        stosb
	add	edi, 3
	dec	ecx
	jnz	@b
	dec	ebx
	jns	.bpp2.channel
        pop     ebx
        ret
endp

;;================================================================================================;;
;;////////////////////////////////////////////////////////////////////////////////////////////////;;
;;================================================================================================;;
;! Below is private data you should never use directly from your code                             ;;
;;================================================================================================;;
;;////////////////////////////////////////////////////////////////////////////////////////////////;;
;;================================================================================================;;
tiff.IFDE_tag_table.begin:
  .tag_100:		dd	0x0100,	tiff._.parse_IFDE.tag_100		; image width
  .tag_101:		dd	0x0101,	tiff._.parse_IFDE.tag_101		; image height (this is called 'length' in spec)
  .tag_102:		dd	0x0102,	tiff._.parse_IFDE.tag_102		; bits per sample
  .tag_103:		dd	0x0103,	tiff._.parse_IFDE.tag_103		; compression
  .tag_106:		dd	0x0106,	tiff._.parse_IFDE.tag_106		; photometric interpretation
  .tag_111:		dd	0x0111,	tiff._.parse_IFDE.tag_111		; strip offsets
  .tag_115:		dd	0x0115,	tiff._.parse_IFDE.tag_115		; samples per pixel
  .tag_116:		dd	0x0116,	tiff._.parse_IFDE.tag_116		; rows per strip
  .tag_117:		dd	0x0117,	tiff._.parse_IFDE.tag_117		; strip byte counts
  .tag_11c:		dd	0x011c,	tiff._.parse_IFDE.tag_11c		; planar configuration
  .tag_13d:		dd	0x013d,	tiff._.parse_IFDE.tag_13d		; predictor
  .tag_140:		dd	0x0140,	tiff._.parse_IFDE.tag_140		; color map
  .tag_152:		dd	0x0152,	tiff._.parse_IFDE.tag_152		; extra samples
tiff.IFDE_tag_table.end:

include 'huffman.asm'		; huffman trees for ccitt1d compression method
