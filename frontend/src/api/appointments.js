import api from "./axios";

export const getAppointments    = (params)   => api.get("/appointments", { params });
export const createAppointment  = (data)     => api.post("/appointments", data);
export const updateAppointment  = (id, data) => api.patch(`/appointments/${id}`, data);
export const cancelAppointment  = (id)       => api.delete(`/appointments/${id}`);
