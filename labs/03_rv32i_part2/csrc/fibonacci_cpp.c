int fibonacci(int n)
{
    static int count = 0;
    count += 1;
    if (n <= 0)
        return 0;
    if (n == 1)
        return 1;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main(int n)
{
    return fibonacci(n);
}
