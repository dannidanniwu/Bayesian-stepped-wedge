data {
  int<lower=0> num_data;            // number of data points (N)
  int num_basis;                    // number of basis functions (p)
  int<lower=0> num_t_ex;            // number of the maximum exposure time points (T_star)
  vector[num_data] y;               // response variable (Y_ijt)
  matrix[num_basis, num_data] B;    // B-spline basis matrix for study time (B)
  matrix[num_basis, num_data] B_star; // B-spline basis matrix for exposure time (B_star)
  matrix[num_basis, num_t_ex] B_test_star; // B-spline basis matrix for a vector of unique exposure time points
  int<lower=0, upper=1> A[num_data];// binary treatment variable (A_jt)
  int<lower=1> num_clusters;           // number of clusters (J)
  int cluster[num_data];               // cluster id for each observation (j)
}

parameters {
  real<lower=1e-3> sigma;           // standard deviation (std) of the observation noise (sigma)
  real<lower=1e-3> sigma_beta_star; // std for the beta_star coefficients (sigma_beta_star)
  real<lower=1e-3> sigma_b;         // std for cluster-level study time effect spline coefficients (sigma_b)
  vector[num_basis] beta_raw;       // raw overall study time effect spline coefficients (non-central parameterization)
  vector[num_basis] beta_star_raw;  // raw spline coefficients for time varying treatment effect (non-central parameterization)
  real alpha;                       // intercept term (alpha)
  real<lower=1e-3> lambda;       // regularization parameters for smoothness (lambda)
  real<lower=1e-3> sigma_beta;      // std for the beta coefficients (sigma_beta)
  matrix[num_clusters, num_basis] b_cluster_raw; // raw cluster-level study time effect spline coefficients (non-central parameterization)
}

transformed parameters {
  vector[num_data] Y_hat;           // expected response variable (E[Y_ijt])
  matrix[num_clusters, num_basis] b_cluster; // cluster-level study time effect spline coefficients (beta_b)
  vector[num_basis] beta;           // overall study time spline coefficients (beta)
  vector[num_basis] beta_star;      // time varying treatment effect spline coefficients (beta_star)

  // Constructing beta_star using non-central parameterization and random walk prior
  beta_star[1] = beta_star_raw[1];
  for (m in 2:num_basis) {
    beta_star[m] = beta_star[m-1] + beta_star_raw[m] * sigma_beta_star;
  }

  // Constructing beta using non-central parameterization and random walk prior
  beta[1] = beta_raw[1];
  for (m in 2:num_basis) {
    beta[m] = beta[m-1] + beta_raw[m] * sigma_beta;
  }
  
  // Constructing cluster-level coefficients using non-central parameterization and Bayesian hierarchical modeling 
  for (m in 1:num_basis) {
    b_cluster[:, m] = beta[m] + sigma_b * b_cluster_raw[:, m];
  }


  for (i in 1:num_data) {
    Y_hat[i] = alpha + dot_product(b_cluster[cluster[i]], B[:, i]) + dot_product(beta_star, B_star[:, i]) * A[i];//B[:,i] will give you a vector that consists of all elements from the ith column of that matrix.
  }
}

model {
  alpha ~ std_normal();             // prior for intercept term (alpha)
  sigma ~ student_t(3, 0, 2.5);     // prior for observation noise (sigma)
  sigma_b ~ student_t(3, 0, 2.5);    // prior for cluster-level study time effect spline std (sigma_b)
  sigma_beta_star ~ std_normal();   // prior for beta_star std (sigma_beta_star)
  sigma_beta ~ std_normal();        // prior for std of beta coefficients (sigma_beta)
  lambda ~ student_t(3, 0, 2.5);    // prior for regularization parameters (lambda)
  
  //parameters for non-central parameterization
  beta_raw ~ std_normal();          
  beta_star_raw ~ std_normal();     
  to_vector(b_cluster_raw) ~ std_normal(); 
  

  for (m in 2:(num_basis - 1)) {
    target += -0.5 * lambda * square(beta[m-1] - beta[m] + beta[m+1]);// smoothness penalty
  }

  // Likelihood function
  y ~ normal(Y_hat, sigma);
}

generated quantities {
  vector[num_data] log_lik;         // log-likelihood for each observation (log_lik)
   real lprior;
  // Calculating log-likelihood
  for (n in 1:num_data) { 
    log_lik[n] = normal_lpdf(y[n] | Y_hat[n], sigma); 
  } 
  
  lprior = std_normal_lpdf(beta_star[1]) + std_normal_lpdf(sigma_beta_star); // prior for beta raw coefficients
}
