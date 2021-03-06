// b_Kb_oipi_pm_plrckm.stan

data {
  // Parameters of priors on metabolism
  real GPP_daily_mu;
  real GPP_daily_sigma;
  real ER_daily_mu;
  real ER_daily_sigma;
  
  // Parameters of hierarchical priors on K600_daily (binned model)
  int <lower=1> b; # number of K600_daily_betas
  vector[b] K600_daily_beta_mu;
  vector[b] K600_daily_beta_sigma;
  real K600_daily_sigma_location;
  real K600_daily_sigma_scale;
  
  // Error distributions
  real err_obs_iid_sigma_location;
  real err_obs_iid_sigma_scale;
  real err_proc_iid_sigma_location;
  real err_proc_iid_sigma_scale;
  
  // Data dimensions
  int<lower=1> d; # number of dates
  int<lower=1> n; # number of observations per date
  
  // Daily data
  vector[d] DO_obs_1;
  int<lower=1,upper=b> discharge_bin_daily[d];
  
  // Data
  vector[d] DO_obs[n];
  vector[d] DO_sat[n];
  vector[d] frac_GPP[n];
  vector[d] frac_ER[n];
  vector[d] frac_D[n];
  vector[d] depth[n];
  vector[d] KO2_conv[n];
}

transformed data {
  vector[d] coef_GPP[n-1];
  vector[d] coef_ER[n-1];
  vector[d] coef_K600_part[n-1];
  vector[d] DO_sat_pairmean[n-1];
  
  for(i in 1:(n-1)) {
    // Coefficients by pairmeans (e.g., mean(frac_GPP[i:(i+1)]) applies to the DO step from i to i+1)
    coef_GPP[i]  <- (frac_GPP[i] + frac_GPP[i+1])/2.0 ./ ((depth[i] + depth[i+1])/2.0);
    coef_ER[i]   <- (frac_ER[i] + frac_ER[i+1])/2.0 ./ ((depth[i] + depth[i+1])/2.0);
    coef_K600_part[i] <- (KO2_conv[i] + KO2_conv[i+1])/2.0 .* (frac_D[i] + frac_D[i+1])/2.0;
    DO_sat_pairmean[i] <- (DO_sat[i] + DO_sat[i+1])/2.0;
  }
}

parameters {
  vector[d] GPP_daily;
  vector[d] ER_daily;
  vector<lower=0>[d] K600_daily;
  
  vector[b] K600_daily_beta;
  real<lower=0> K600_daily_sigma_scaled;
  
  real<lower=0> err_obs_iid_sigma_scaled;
  real<lower=0> err_proc_iid_sigma_scaled;
  
  vector[d] err_proc_iid[n-1];
}

transformed parameters {
  real K600_daily_sigma;
  vector[d] K600_daily_pred;
  real<lower=0> err_obs_iid_sigma;
  real<lower=0> err_proc_iid_sigma;
  vector[d] DO_mod[n];
  
  // Rescale pooling & error distribution parameters
  // lnN(location,scale) = exp(location)*(exp(N(0,1))^scale)
  K600_daily_sigma <- exp(K600_daily_sigma_location) * pow(exp(K600_daily_sigma_scaled), K600_daily_sigma_scale);
  err_obs_iid_sigma <- exp(err_obs_iid_sigma_location) * pow(exp(err_obs_iid_sigma_scaled), err_obs_iid_sigma_scale);
  err_proc_iid_sigma <- exp(err_proc_iid_sigma_location) * pow(exp(err_proc_iid_sigma_scaled), err_proc_iid_sigma_scale);
  
  // Hierarchical, binned model of K600_daily
  K600_daily_pred <- K600_daily_beta[discharge_bin_daily];
  
  // Model DO time series
  // * pairmeans version
  // * observation error
  // * IID process error
  // * reaeration depends on DO_mod
  
  // DO model
  DO_mod[1] <- DO_obs_1;
  for(i in 1:(n-1)) {
    DO_mod[i+1] <- (
      DO_mod[i] +
      err_proc_iid[i] +
      GPP_daily .* coef_GPP[i] +
      ER_daily .* coef_ER[i] +
      K600_daily .* coef_K600_part[i] .* (DO_sat_pairmean[i] - DO_mod[i]/2.0)
    ) ./ (1.0 + K600_daily .* coef_K600_part[i] / 2.0);
  }
}

model {
  // Process error
  for(i in 1:(n-1)) {
    // Independent, identically distributed process error
    err_proc_iid[i] ~ normal(0, err_proc_iid_sigma);
  }
  // SD (sigma) of the IID process errors
  err_proc_iid_sigma_scaled ~ normal(0, 1);
  
  // Independent, identically distributed observation error
  for(i in 2:n) {
    DO_obs[i] ~ normal(DO_mod[i], err_obs_iid_sigma);
  }
  // SD (sigma) of the observation errors
  err_obs_iid_sigma_scaled ~ normal(0, 1);
  
  // Daily metabolism priors
  GPP_daily ~ normal(GPP_daily_mu, GPP_daily_sigma);
  ER_daily ~ normal(ER_daily_mu, ER_daily_sigma);
  K600_daily ~ normal(K600_daily_pred, K600_daily_sigma);

  // Hierarchical constraints on K600_daily (binned model)
  K600_daily_beta ~ normal(K600_daily_beta_mu, K600_daily_beta_sigma);
  K600_daily_sigma_scaled ~ normal(0, 1);
}
