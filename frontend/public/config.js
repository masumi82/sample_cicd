// This file is overwritten by CD pipeline with the actual values.
// For local dev, leave API_URL empty so requests go same-origin (Vite proxy
// in vite.config.js strips "/api" and forwards to http://localhost:8000).
// Empty Cognito vars disable auth in the SPA (PrivateRoute passes through).
window.APP_CONFIG = {
  API_URL: "",
  COGNITO_USER_POOL_ID: "",
  COGNITO_APP_CLIENT_ID: "",
};
