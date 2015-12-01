# LI
# Kevin
# 260565522
.data
displayBuffer:  .space 0x80000  # space for 512x256 bitmap display 
errorBuffer:    .space 0x80000  # space to store match function
templateBuffer: .space 0x400	# space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw"  # filename of image to load 
templateFileName: .asciiz "template8x8gs.raw"	     # filename of template to load
# struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 128  imageFileName
errorBufferInfo:    .word errorBuffer    512 128  0
templateBufferInfo: .word templateBuffer 8   8    templateFileName

.text
main:	la $a0, imageBufferInfo
	jal loadImage
	la $a0, templateBufferInfo
	jal loadImage
	la $a0, imageBufferInfo
	la $a1, templateBufferInfo
	la $a2, errorBufferInfo
	jal matchTemplate        # MATCHING DONE HERE
	la $a0, errorBufferInfo
	jal findBest
	la $a0, imageBufferInfo
	move $a1, $v0
	jal highlight
	la $a0, errorBufferInfo	
	jal processError
	li $v0, 10		# exit
	syscall
	

##########################################################
# matchTemplate( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplate:	
		lw $a3, 0($a0) # int *imageBuffer
		lw $t5, 0($a1) # address of templateBuffer
		lw $t6, 0($a2) # address of errorBuffer
		#addi $t0, $0, 4 # need number 4 for word alignment
		lw $a1, 8($a0) # int height
		lw $a2, 4($a0) # int width
		#mult $a1, $t0 # multiply to get width words. each pixel is 4 bytes!
		#mflo $a1 # return the total pixel width to a1
		#mult $a2, $t0 # multiply to get height words.
		#mflo $a2 # return the total pixel height to a2
		subi $a1, $a1, 7 # subtract 7 from width to use for slt later 
		subi $a2, $a2, 7 # subtract 7 from height to use for slt later
		add $t1, $0, $0 # initialize mutable height at zero
mLoopH:		slt $t0, $t1, $a1 # check if height is done looping
		beqz $t0, heightEnd # if it is done, then end outermost loop
		add $t2, $0, $0 # initialize mutable image width to zero
mLoopW: 	slt $t0, $t2, $a2 # check if width is done looping
		beqz $t0, widthEnd # if it is done, then end width loop
		add $t3, $0, $0 #initialize template loop height at zero
		add $s0, $0, $0 # initialize s0 register at zero (in preparation for saving the SAD[x,y]) 
tLoopH:		slti $t0, $t3, 8 # see if finished looping over height of template
		beqz $t0, tHeightEnd # if yes, jump to tWidthEnd and then go to mLoopH to next height
		add $t4, $0, $0 #initialize template loop width at zero
tLoopW:		slti $t0, $t4, 8 # see if finished looping over width of the template
		beqz $t0, tWidthEnd # if yes, move on to next width unit
		# $a3 = address of displayBuffer
		# $t1 = current height of image offset (outer)
		# $t2 = current width of image offset (inner)
		# $t3 = current height of template (also offset for image width) (outer)
		# $t4 = current width of template (also offset for image height) (inner)
		# $t5 = address of templateBuffer
		# $t6 = address of errorBuffer
		# $a1 = max height of template - 7 in pixels
		# $a2 = max width of template - 7 in pixels
		# calculate absolute differences and set values in errorbuffer here
		# first: get base pixel offset
		addi $a0, $0, 4 # need 4
		addi $t0, $a2, 7 # get the proper full width of the image
		mult $t1, $t0 # multiply full width by current height of image
		mflo $t7 # get the product (image height offset)
		add $t7, $t2, $t7 # add current image width offset to get the base pixel offset/4
		#mult $t7, $a0 # multiply the base pixel offset/4 by 4 to get the number of words offset for the image
		#mflo $t7 # store the product in t7
		# second: add template offset to base pixel offset
		mult $t3, $t0 # multiply total width (512) by current height of template
		mflo $t8 # get the product, which is the template height offset
		add $t8, $t8, $t4 # add template width offset
		#mult $t8, $a0 # multiply by four to get word offset
		#mflo $t8 # store product in t8
		#add $t9, $t8, $0 # add to t9 to use later (this is template height and width offset) 
		add $t7, $t8, $t7 # add template height and width offset to base offset
		mult $a0, $t7 # mult by four. image offset including template offset.
		mflo $t7 # store image offset including template offset in t7
		
		# $t7 now contains the proper image offset that we can use to compare with the template!
		# now we need to get the address of the pixel because we can't use registers as offsets
		add $t7, $t7, $a3 # add displayBuffer address to $t7 to get address of image pixel
#		# now we compare and do error analysis between the template pixel and the image pixel
		
		# t7 has displayBuffer address of image pixel
		# t8 has errorBuffer address of error memory storage
		# t5 has templateBuffer base address
		# t9 has template height and width offset
		# t3 has current template height (0..7)
		# t4 has current template width (0..7)
		addi $a0, $0, 8 # need 8
		mult $t3, $a0 # mult 8 by template height
		mflo $t8 # get product. this is height offset of template
		add $t8, $t8, $t4 # add template width offset
		addi $a0, $0, 4 # need 4
		mult $t8, $a0 # mult to get word offset
		mflo $t8 # store product
		add $t9, $t8, $t5 # add to get proper template address location in t9
		lbu $t7, 1($t7) # load pixel value of image into t7
		lbu $t9, 1($t9) # load pixel value of template into t8
		#srl $t7, $t7, 16 # shift right by 16 bits to keep the top byte in the image pixel (since all we care about is intensity)
		#srl $t9, $t9, 16 # do the same shift with the template pixel
		subu $t7, $t7, $t9 # subtract the intensities and store in t7
		# now we check for an absolute value in t7
		#slt $t0, $t7, $0 # check if it's less than zero
		#beqz $t0, nope # if it's greater than zero, skip to nope.
		#sub $t7, $0, $t7 # if it's less than zero, subtract zero by t7 and store in t7
		abs $t7, $t7 # TEST: absolute value
nope:		addu $s0, $t7, $s0 # add absolute error to $s0. will save it to the error buffer after the template is done matching.
		# DONE DOING THINGS.				
		addi $t4, $t4, 1 # add one to height after done comparing this height
		j tLoopW # go back to top of the template width loop
tWidthEnd: 	addi $t3, $t3, 1 # add one to width after done comparing this column of the template
		j tLoopH # go back to top of template height loop
tHeightEnd:	addi $a0, $a2, 7 # get the proper full width of the image
		mult $t1, $a0 # multiply full width by current height of image
		mflo $t7 # get the product
		add $t7, $t2, $t7 # add current image width offset to get the base pixel offset/4
		add $a0, $0, 4 # need number 4
		mult $a0, $t7 # multiply by 4 to get word offset
		mflo $t7 # get product and store in t7. This is proper word offset (x,y in SAD[x,y])
		add $t7, $t6, $t7 # add errorbuffer address to base offset to get address at which to store error
		sw $s0, 0($t7) # save SAD into errorBuffer address
		addi $t2, $t2, 1 # add one to width of the image
		j mLoopW # jump back to top of the loop to compare the new image height with the template
widthEnd:	addi $t1, $t1, 1 # add one to height of the image
		j mLoopH # jump back to the top of the image width loop in order to compare the next column of image
heightEnd:	jr $ra # finish looping, all memory in error buffer now set to absolute differences
	
	
	
	
###############################################################
# loadImage( bufferInfo* imageBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
loadImage:	lw $a3, 0($a0)  # int* buffer
		lw $a1, 4($a0)  # int width
		lw $a2, 8($a0)  # int height
		lw $a0, 12($a0) # char* filename
		mul $t0, $a1, $a2 # words to read (width x height) in a2
		sll $t0, $t0, 2	  # multiply by 4 to get bytes to read
		li $a1, 0     # flags (0: read, 1: write)
		li $a2, 0     # mode (unused)
		li $v0, 13    # open file, $a0 is null-terminated string of file name
		syscall
		move $a0, $v0     # file descriptor (negative if error) as argument for read
  		move $a1, $a3     # address of buffer to which to write
		move $a2, $t0	  # number of bytes to read
		li  $v0, 14       # system call for read from file
		syscall           # read from file
        	# $v0 contains number of characters read (0 if end-of-file, negative if error).
        	# We'll assume that we do not need to be checking for errors!
		# Note, the bitmap display doesn't update properly on load, 
		# so let's go touch each memory address to refresh it!
		move $t0, $a3	   # start address
		add $t1, $a3, $a2  # end address
loadloop:	lw $t2, ($t0)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		bne $t0, $t1, loadloop
		jr $ra
		
		
#####################################################
# (offset, score) = findBest( bufferInfo errorBuffer )
# Returns the address offset and score of the best match in the error Buffer
findBest:	lw $t0, 0($a0)     # load error buffer start address	
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		li $v0, 0		# address of best match	
		li $v1, 0xffffffff 	# score of best match	
		lw $a1, 4($a0)    # load width
        	addi $a1, $a1, -7 # initialize column count to 7 less than width to account for template
fbLoop:		lw $t9, 0($t0)        # score
		sltu $t8, $t9, $v1    # better than best so far?
		beq $t8, $zero, notBest
		move $v0, $t0
		move $v1, $t9
notBest:	addi $a1, $a1, -1
		bne $a1, $0, fbNotEOL # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width
        	addi $a1, $a1, -7     # column count for next line is 7 less than width
        	addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
fbNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, fbLoop
		lw $t0, 0($a0)     # load error buffer start address	
		sub $v0, $v0, $t0  # return the offset rather than the address
		jr $ra
		

#####################################################
# highlight( bufferInfo imageBuffer, int offset )
# Applies green mask on all pixels in an 8x8 region
# starting at the provided addr.
highlight:	lw $t0, 0($a0)     # load image buffer start address
		add $a1, $a1, $t0  # add start address to offset
		lw $t0, 4($a0) 	# width
		sll $t0, $t0, 2	
		li $a2, 0xff00 	# highlight green
		li $t9, 8	# loop over rows
highlightLoop:	lw $t3, 0($a1)		# inner loop completely unrolled	
		and $t3, $t3, $a2
		sw $t3, 0($a1)
		lw $t3, 4($a1)
		and $t3, $t3, $a2
		sw $t3, 4($a1)
		lw $t3, 8($a1)
		and $t3, $t3, $a2
		sw $t3, 8($a1)
		lw $t3, 12($a1)
		and $t3, $t3, $a2
		sw $t3, 12($a1)
		lw $t3, 16($a1)
		and $t3, $t3, $a2
		sw $t3, 16($a1)
		lw $t3, 20($a1)
		and $t3, $t3, $a2
		sw $t3, 20($a1)
		lw $t3, 24($a1)
		and $t3, $t3, $a2
		sw $t3, 24($a1)
		lw $t3, 28($a1)
		and $t3, $t3, $a2
		sw $t3, 28($a1)
		add $a1, $a1, $t0	# increment address to next row	
		add $t9, $t9, -1	# decrement row count
		bne $t9, $zero, highlightLoop
		jr $ra

######################################################
# processError( bufferInfo error )
# Remaps scores in the entire error buffer. The best score, zero, 
# will be bright green (0xff), and errors bigger than 0x4000 will
# be black.  This is done by shifting the error by 5 bits, clamping
# anything bigger than 0xff and then subtracting this from 0xff.
processError:	lw $t0, 0($a0)     # load error buffer start address
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		lw $a1, 4($a0)     # load width as column counter
        	addi $a1, $a1, -7  # initialize column count to 7 less than width to account for template
pebLoop:	lw $v0, 0($t0)        # score
		srl $v0, $v0, 5       # reduce magnitude 
		slti $t2, $v0, 0x100  # clamp?
		bne  $t2, $zero, skipClamp
		li $v0, 0xff          # clamp!
skipClamp:	li $t2, 0xff	      # invert to make a score
		sub $v0, $t2, $v0
		sll $v0, $v0, 8       # shift it up into the green
		sw $v0, 0($t0)
		addi $a1, $a1, -1        # decrement column counter	
		bne $a1, $0, pebNotEOL   # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width to reset column counter
        	addi $a1, $a1, -7     # column count for next line is 7 less than width
        	addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
pebNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, pebLoop
		jr $ra
