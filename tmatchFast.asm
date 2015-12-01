# LAST NAME
# First name
# Student number
.data
displayBuffer:  .space 0x80000  # space for 512x256 bitmap display 
errorBuffer:    .space 0x80000  # space to store match function
templateBuffer: .space 0x400	# space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw"  # filename of image to load 
templateFileName: .asciiz "template8x8gs.raw"	     # filename of template to load
# struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 256  imageFileName
errorBufferInfo:    .word errorBuffer    512 256  0
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
		# $a0 = imageBufferInfo
		# $a1 = templateBufferInfo
		# $a2 = errorBufferInfo
		addi $sp, $sp, -8 # make room on the stack
		sw $s0, 0($sp) # save s0 on stack because we need it
		sw $s1, 4($sp) # save s1 on stack because we need it
		add $a3, $0, $0 # init template height counter
templateH:	slti $t0, $a3, 8 # check if less than 8
		beqz $t0, matchDone # if not less, then we're done!
		addi $t9, $0, 32 # need 4*8
		mult $t9, $a3 # multiply current number of rows by height offset.
		mflo $t9 # get product, store in t9
		lw $t0, 0($a1) # store base address of template in t0
		add $t9, $t0, $t9 # add the height offset to get the address of the leftmost pixel of the current row (0)
		lbu $t0, 1($t9) # load byte of intensity of leftmost pixel in current row
		lbu $t1, 5($t9) # add 4 to get the next pixel (1)
		lbu $t2, 9($t9) # add 4 to get the next pixel (2)
		lbu $t3, 13($t9) # add 4 to get the next pixel (3)
		lbu $t4, 17($t9) # add 4 to get the next pixel (4)		
		lbu $t5, 21($t9) # add 4 to get the next pixel (5)
		lbu $t6, 25($t9) # add 4 to get the next pixel (6)
		lbu $t7, 29($t9) # add 4 to get the next pixel (7)
		# we have loaded all the byte intensities of the pixels in the row in temp registers
		# now we must handling looping over the image.
		add $v0, $0, $0 # initialize image height counter
imageH:		lw $t9, 8($a0) # load the total height of the image
		sub $t9, $t9, 7 # subtract seven because we skip the last 7 rows
		slt $t9, $v0, $t9 # see if we're done looping over height
		beqz $t9, imgHeightDone # if done looping over height, then skip to "imgHeightDone"
		add $v1, $0, $0 # initialize image width counter
imageW:		lw $t9, 4($a0) # load the total width of the image
		sub $t9, $t9, 7 # subtract seven because skipping the last 7 columns
		slt $t9, $v1, $t9 # check if we're done looping over the image width
		beqz $t9, imgWidthDone # if we're done looping over the width then we skip to "imgHeightDone"
		# now we do cool things
		# t0 - t7 contain the byte intensities of the current row of the template pixels that we're interested in
		# a0 = imageBufferInfo
		# a1 = templateBufferInfo
		# a2 = errorBufferInfo
		# v0 = current image height
		# v1 = current image width
		# now, at the curret v0,v1 pair, we store the SAD of the current row of image pixels - current row of template pxls
		lw $t9, 4($a0) # load width of image buffer into t8
		add $t8, $v0, $a3 # add the current template height (using t9 for comparison since it needs the template height too)
		mult $t9, $t8 # multiply total width by current image height + template height (this is for imageBuffer address)
		mflo $t8 # store product in t8
		mult $t9, $v0 # multiply total width by current image height (this is for errorBuffer address)
		mflo $t9 # store in t9
		add $t8, $t8, $v1 # add current width to t8, obtaining offset/4 (this is for imagebuffer address)
		add $t9, $t9, $v1 # add current width to t9, this is offset/4 (this is for errorBuffer addresS)
		addi $s1, $0, 4 # get number four
		mult $t8, $s1 # multiply to get word offset
		mflo $t8 # store in t8
		mult $t9, $s1 # multiply the original (for errorBuffer address) offset by 4
		mflo $t9 # store in t9
		lw $s0, 0($a2) # get address of errorBuffer
		add $s0, $s0, $t9 # add total offset to address of errorbuffer. This is the address to which we save SAD
		lw $s1, 0($s0) # load current SAD into s1
		lw $t9, 0($a0) # get address of imagebuffer
		add $t8, $t8, $t9 # add total offset to address of imagebuffer. this is the base address from which we compare the row of pxls!
		#now we do the unrolling, comparison, and adding SAD to s1 (current SAD)
		lbu $t9, 1($t8) # load byte of intensity from image (0)
		sub $t9, $t9, $t0 # subtract to get difference from template row[0]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 5($t8) # load byte of intensity from image (1)
		sub $t9, $t9, $t1 # subtract to get difference from template row[1]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 9($t8) # load byte of intensity from image (2)
		sub $t9, $t9, $t2 # subtract to get difference from template row[2]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 13($t8) # load byte of intensity from image (3)
		sub $t9, $t9, $t3 # subtract to get difference from template row[3]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 17($t8) # load byte of intensity from image (4)
		sub $t9, $t9, $t4 # subtract to get difference from template row[4]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 21($t8) # load byte of intensity from image (5)
		sub $t9, $t9, $t5 # subtract to get difference from template row[5]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 25($t8) # load byte of intensity from image (6)
		sub $t9, $t9, $t6 # subtract to get difference from template row[6]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		lbu $t9, 29($t8) # load byte of intensity from image (7)
		sub $t9, $t9, $t7 # subtract to get difference from template row[7]
		abs $t9, $t9 # get absolute value of difference
		add $s1, $s1, $t9 # add abs(SAD)
		sw $s1, 0($s0) # save s1, the new SAD, into the location at s0
		addi $v1, $v1, 1 # increment image width counter
		j imageW
imgWidthDone: 	addi $v0, $v0, 1 # increment img height counter
		j imageH # jump back to iterate on the next image height		
imgHeightDone:	addi $a3, $a3, 1 # increment template height counter
		j templateH # jump back to top of template height loop now that we have a new template height
matchDone:	lw $s0, 0($sp) # return s0
		lw $s1, 4($sp) # return s1
		add $sp, $sp, 8 # return sp back to original position
		jr $ra	
	
	
	
	
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
