// amazon-cognito-identity-js は ~60KB のため、初回利用時まで動的 import で遅延読み込みする
let _modulePromise = null;
function loadCognito() {
  if (!_modulePromise) {
    _modulePromise = import("amazon-cognito-identity-js");
  }
  return _modulePromise;
}

const getConfig = () => {
  const cfg = window.APP_CONFIG || {};
  return {
    UserPoolId: cfg.COGNITO_USER_POOL_ID || "",
    ClientId: cfg.COGNITO_APP_CLIENT_ID || "",
  };
};

// ライブラリを読み込まずに同期判定できるよう設定の有無だけ確認
export function isAuthConfigured() {
  const { UserPoolId, ClientId } = getConfig();
  return Boolean(UserPoolId && ClientId);
}

let _userPool = null;

export async function getUserPool() {
  if (_userPool) return _userPool;
  const config = getConfig();
  if (!config.UserPoolId || !config.ClientId) return null;
  const { CognitoUserPool } = await loadCognito();
  _userPool = new CognitoUserPool(config);
  return _userPool;
}

export async function getCurrentUser() {
  const pool = await getUserPool();
  return pool ? pool.getCurrentUser() : null;
}

export async function getIdToken() {
  const user = await getCurrentUser();
  if (!user) return null;
  return new Promise((resolve) => {
    user.getSession((err, session) => {
      if (err || !session || !session.isValid()) {
        resolve(null);
        return;
      }
      resolve(session.getIdToken().getJwtToken());
    });
  });
}

export async function signIn(email, password) {
  const pool = await getUserPool();
  if (!pool) throw new Error("Cognito not configured");
  const { CognitoUser, AuthenticationDetails } = await loadCognito();
  return new Promise((resolve, reject) => {
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

export async function signUp(email, password) {
  const pool = await getUserPool();
  if (!pool) throw new Error("Cognito not configured");
  return new Promise((resolve, reject) => {
    pool.signUp(email, password, [], null, (err, result) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(result);
    });
  });
}

export async function confirmSignUp(email, code) {
  const pool = await getUserPool();
  if (!pool) throw new Error("Cognito not configured");
  const { CognitoUser } = await loadCognito();
  return new Promise((resolve, reject) => {
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

export async function signOut() {
  const user = await getCurrentUser();
  if (user) user.signOut();
}
