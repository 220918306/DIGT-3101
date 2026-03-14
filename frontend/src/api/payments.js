import api from "./axios";

export const createPayment = (data) => api.post("/payments", data);
