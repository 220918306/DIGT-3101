import api from "./axios";

export const getUnits          = (params) => api.get("/units", { params });
export const getUnit           = (id)     => api.get(`/units/${id}`);
export const getAvailableSlots = (id, date) => api.get(`/units/${id}/available_slots`, { params: { date } });
