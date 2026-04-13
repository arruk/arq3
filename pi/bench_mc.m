n = 50000;
x = rand(1,n);
y = rand(1,n);

tic;
pi_montecarlo(n, x, y)
toc;

tic;
vec_pi_montecarlo(n, x, y)
toc;
