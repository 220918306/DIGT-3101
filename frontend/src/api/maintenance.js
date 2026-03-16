import api from "./axios";

export const getTickets      = ()         => api.get("/maintenance_tickets");
export const createTicket    = (data)     => api.post("/maintenance_tickets", data);
export const updateTicket    = (id, data) => api.patch(`/maintenance_tickets/${id}`, data);
export const billDamage      = (id, data) => api.post(`/maintenance_tickets/${id}/bill_damage`, data);
