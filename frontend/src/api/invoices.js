import api from "./axios";

export const getInvoices       = (params) => api.get("/invoices", { params });
export const getInvoice        = (id)     => api.get(`/invoices/${id}`);
export const generateInvoices  = ()       => api.post("/invoices/generate");
export const updateInvoiceUtilities = (id, body) => api.patch(`/invoices/${id}/utilities`, body);
