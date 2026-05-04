import { createClient } from '@supabase/supabase-js'

// Vite kullanıyorsa import.meta.env, Create React App ise process.env.REACT_APP_ kullanılır.
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)