import api from "./axios";

export const getLetters = () => api.get("/letters");
export const signLetter = (id) => api.post(`/letters/${id}/sign`);
