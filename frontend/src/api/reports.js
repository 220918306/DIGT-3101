import api from "./axios";

export const getOccupancyReport   = ()       => api.get("/reports/occupancy");
export const getRevenueReport     = (params) => api.get("/reports/revenue", { params });
export const getMaintenanceReport = ()       => api.get("/reports/maintenance");
