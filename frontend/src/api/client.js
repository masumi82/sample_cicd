const getApiUrl = () => {
  if (window.APP_CONFIG && window.APP_CONFIG.API_URL) {
    return window.APP_CONFIG.API_URL;
  }
  return "http://localhost:8000";
};

const API_URL = getApiUrl();

async function request(path, options = {}) {
  const url = `${API_URL}${path}`;
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options,
  });
  if (!response.ok) {
    const error = await response.json().catch(() => ({}));
    throw new Error(error.detail || `Request failed: ${response.status}`);
  }
  if (response.status === 204) return null;
  return response.json();
}

// Tasks API
export function getTasks() {
  return request("/tasks");
}

export function getTask(id) {
  return request(`/tasks/${id}`);
}

export function createTask(data) {
  return request("/tasks", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export function updateTask(id, data) {
  return request(`/tasks/${id}`, {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

export function deleteTask(id) {
  return request(`/tasks/${id}`, { method: "DELETE" });
}

// Attachments API
export function getAttachments(taskId) {
  return request(`/tasks/${taskId}/attachments`);
}

export function createAttachment(taskId, filename, contentType) {
  return request(`/tasks/${taskId}/attachments`, {
    method: "POST",
    body: JSON.stringify({ filename, content_type: contentType }),
  });
}

export function getAttachment(taskId, attachmentId) {
  return request(`/tasks/${taskId}/attachments/${attachmentId}`);
}

export function deleteAttachment(taskId, attachmentId) {
  return request(`/tasks/${taskId}/attachments/${attachmentId}`, {
    method: "DELETE",
  });
}

export async function uploadToPresignedUrl(presignedUrl, file) {
  const response = await fetch(presignedUrl, {
    method: "PUT",
    headers: { "Content-Type": file.type },
    body: file,
  });
  if (!response.ok) {
    throw new Error(`Upload failed: ${response.status}`);
  }
}
