int ffs(int i)
{
    int bit = 0;
    if (i == 0)
    {
        return 0;
    }

    for (bit = 1; !(i & 1) && bit < sizeof(int) * 8; bit++)
    {
        i >>= 1;
    }

    return bit;
}