import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
} from "amazon-cognito-identity-js";

const getConfig = () => {
  const cfg = window.APP_CONFIG || {};
  return {
    UserPoolId: cfg.COGNITO_USER_POOL_ID || "",
    ClientId: cfg.COGNITO_APP_CLIENT_ID || "",
  };
};

let _userPool = null;

export function getUserPool() {
  if (!_userPool) {
    const config = getConfig();
    if (!config.UserPoolId || !config.ClientId) return null;
    _userPool = new CognitoUserPool(config);
  }
  return _userPool;
}

export function getCurrentUser() {
  const pool = getUserPool();
  return pool ? pool.getCurrentUser() : null;
}

export function getIdToken() {
  return new Promise((resolve, reject) => {
    const user = getCurrentUser();
    if (!user) {
      resolve(null);
      return;
    }
    user.getSession((err, session) => {
      if (err || !session || !session.isValid()) {
        resolve(null);
        return;
      }
      resolve(session.getIdToken().getJwtToken());
    });
  });
}

export function signIn(email, password) {
  return new Promise((resolve, reject) => {
    const pool = getUserPool();
    if (!pool) {
      reject(new Error("Cognito not configured"));
      return;
    }
    const user = new CognitoUser({ Username: email, Pool: pool });
    const authDetails = new AuthenticationDetails({
      Username: email,
      Password: password,
    });
    user.authenticateUser(authDetails, {
      onSuccess: (result) => resolve(result),
      onFailure: (err) => reject(err),
    });
  });
}

export function signUp(email, password) {
  return new Promise((resolve, reject) => {
    const pool = getUserPool();
    if (!pool) {
      reject(new Error("Cognito not configured"));
      return;
    }
    pool.signUp(email, password, [], null, (err, result) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(result);
    });
  });
}

export function confirmSignUp(email, code) {
  return new Promise((resolve, reject) => {
    const pool = getUserPool();
    if (!pool) {
      reject(new Error("Cognito not configured"));
      return;
    }
    const user = new CognitoUser({ Username: email, Pool: pool });
    user.confirmRegistration(code, true, (err, result) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(result);
    });
  });
}

export function signOut() {
  const user = getCurrentUser();
  if (user) user.signOut();
}
