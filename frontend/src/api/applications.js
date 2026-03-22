import api from "./axios";

export const getApplications   = (params) => api.get("/applications", { params });
export const createApplication = (data)   => api.post("/applications", data);
export const approveApplication = (id, data) => api.patch(`/applications/${id}/approve`, data);
export const rejectApplication  = (id, data) => api.patch(`/applications/${id}/reject`, data);
export const withdrawApplication = (id) => api.delete(`/applications/${id}`);
