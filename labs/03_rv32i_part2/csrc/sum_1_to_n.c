int sum_1_to_n(int n)
{
	if (n <= 0) return 0;
	return n + sum_1_to_n(n - 1);
}

int main(int argv)
{
	return sum_1_to_n(argv);
}