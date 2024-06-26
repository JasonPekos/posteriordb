// drive model (normal dist)
data {
  int<lower=1> K; // number of states (1 = none, 2 = drive)
  int<lower=1> N; // length of process
  array[N] real u; // 1/speed
  array[N] real v; // hoop distance
  matrix<lower=0>[K, K] alpha; // transit prior
  real<lower=0> tau; // sd u
  real<lower=0> rho; // sd v
}
parameters {
  simplex[K] theta1;
  simplex[K] theta2;
  // enforce an ordering: phi[1] <= phi[2]
  ordered[K] phi; // emission parameter for 1/speed
  ordered[K] lambda; // emission parameter for hoop dist
}
transformed parameters {
  array[K] simplex[K] theta; // transit probs
  theta[1] = theta1;
  theta[2] = theta2;
}
model {
  // priors
  for (k in 1 : K) {
    target += dirichlet_lpdf(theta[k] | alpha[k,  : ]');
  }
  target += normal_lpdf(phi[1] | 0, 1);
  target += normal_lpdf(phi[2] | 3, 1);
  target += normal_lpdf(lambda[1] | 0, 1);
  target += normal_lpdf(lambda[2] | 3, 1);
  // forward algorithm
  {
    array[K] real acc;
    array[N, K] real gamma;
    for (k in 1 : K) {
      gamma[1, k] = normal_lpdf(u[1] | phi[k], tau)
                    + normal_lpdf(v[1] | lambda[k], rho);
    }
    for (t in 2 : N) {
      for (k in 1 : K) {
        for (j in 1 : K) {
          acc[j] = gamma[t - 1, j] + log(theta[j, k])
                   + normal_lpdf(u[t] | phi[k], tau)
                   + normal_lpdf(v[t] | lambda[k], rho);
        }
        gamma[t, k] = log_sum_exp(acc);
      }
    }
    target += log_sum_exp(gamma[N]);
  }
}
generated quantities {
  array[N] int<lower=1, upper=K> z_star;
  real log_p_z_star;
  // Viterbi algorithm
  {
    array[N, K] int back_ptr;
    array[N, K] real best_logp;
    for (k in 1 : K) {
      best_logp[1, K] = normal_lpdf(u[1] | phi[k], tau)
                        + normal_lpdf(v[1] | lambda[k], rho);
    }
    for (t in 2 : N) {
      for (k in 1 : K) {
        best_logp[t, k] = negative_infinity();
        for (j in 1 : K) {
          real logp;
          logp = best_logp[t - 1, j] + log(theta[j, k])
                 + normal_lpdf(u[t] | phi[k], tau)
                 + normal_lpdf(v[t] | lambda[k], rho);
          if (logp > best_logp[t, k]) {
            back_ptr[t, k] = j;
            best_logp[t, k] = logp;
          }
        }
      }
    }
    log_p_z_star = max(best_logp[N]);
    for (k in 1 : K) {
      if (best_logp[N, k] == log_p_z_star) {
        z_star[N] = k;
      }
    }
    for (t in 1 : (N - 1)) {
      z_star[N - t] = back_ptr[N - t + 1, z_star[N - t + 1]];
    }
  }
}


