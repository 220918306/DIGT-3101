import api from "./axios";

export const getLeases  = (params) => api.get("/leases", { params });
export const getLease   = (id)     => api.get(`/leases/${id}`);
export const createLease = (data)  => api.post("/leases", data);
export const updateLease = (id, data) => api.patch(`/leases/${id}`, data);
export const sendLeaseAgreement = (id) => api.post(`/leases/${id}/send_agreement`);
