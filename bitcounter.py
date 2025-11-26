def getOneBits(n):
    # Convert to binary without the '0b' prefix
    b = bin(n)[2:]

    positions = []
    
    # Loop through the binary string
    for i, bit in enumerate(b):
        if bit == '1':
            # Positions start at 1
            positions.append(i + 1)

    # First element is count of 1 bits
    return [len(positions)] + positions
