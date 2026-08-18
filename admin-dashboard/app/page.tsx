'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Activity, Award, Volume2, Users, CheckCircle2, AlertCircle, RefreshCw, Eye, Check, X, ShieldAlert, LogOut } from 'lucide-react';

interface UserItem {
  id: number;
  username: string;
  email: string;
  registration_screenshot: string;
  is_approved: number;
  is_active: number;
  registration_month: string;
  last_payment_month: string;
  created_at: string;
  payment_status_badge: string;
  status_text: string;
}

interface PaymentRequest {
  id: number;
  user_id: number;
  username: string;
  month: string;
  year: string;
  screenshot_url: string;
  status: string;
  created_at: string;
}

interface SessionLog {
  id?: number;
  student: string;
  alphabet: string;
  spoken_sound?: string;
  whisper_transcription?: string;
  accuracy: number;
  passed: boolean | number;
  timestamp: string;
}

export default function AdminDashboard() {
  const router = useRouter();
  const [users, setUsers] = useState<UserItem[]>([]);
  const [payments, setPayments] = useState<PaymentRequest[]>([]);
  const [stats, setStats] = useState({
    total_sessions: 0,
    passed_sessions: 0,
    pass_rate_pct: 0,
    avg_accuracy_pct: 0,
    recent_logs: [] as SessionLog[]
  });

  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState<'users' | 'analytics'>('users');
  const [selectedImage, setSelectedImage] = useState<string | null>(null);

  const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://naila-teaching-alphabets.onrender.com';

  useEffect(() => {
    const token = localStorage.getItem('vaila_admin_token');
    if (!token) {
      router.push('/login');
    }
  }, [router]);

  const fetchData = async () => {
    setLoading(true);
    try {
      // 1. Fetch Users & Payment Requests
      const userRes = await fetch(`${API_URL}/api/admin/users`);
      if (userRes.ok) {
        const data = await userRes.json();
        setUsers(data.users || []);
        setPayments(data.payments || []);
      }

      // 2. Fetch Practice Analytics Stats
      const statsRes = await fetch(`${API_URL}/api/stats`);
      if (statsRes.ok) {
        const data = await statsRes.json();
        setStats(data);
      }
    } catch (e) {
      console.log('Error fetching admin data:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 6000);
    return () => clearInterval(interval);
  }, []);

  const handleApproveUser = async (user: UserItem) => {
    try {
      const formData = new FormData();
      formData.append('user_id', String(user.id));
      formData.append('username', user.username);
      const res = await fetch(`${API_URL}/api/admin/approve-user`, {
        method: 'POST',
        body: formData
      });
      if (res.ok) {
        alert(`User '${user.username}' has been approved successfully!`);
        fetchData();
      }
    } catch (e) {
      console.error(e);
    }
  };

  const handleDeactivateUser = async (user: UserItem) => {
    try {
      const formData = new FormData();
      formData.append('user_id', String(user.id));
      formData.append('username', user.username);
      const res = await fetch(`${API_URL}/api/admin/deactivate-user`, {
        method: 'POST',
        body: formData
      });
      if (res.ok) {
        alert(`User '${user.username}' deactivated.`);
        fetchData();
      }
    } catch (e) {
      console.error(e);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('vaila_admin_token');
    router.push('/login');
  };

  return (
    <main className="dashboard-container">
      {/* Header */}
      <header className="header-nav" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div className="logo-group">
          <div className="logo-badge">V</div>
          <div className="title-text">
            <h1>Vaila Teaching Admin Portal</h1>
            <p>Registration Approval, Monthly Fee Alerts & Analytics</p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={fetchData}
            style={{
              background: 'rgba(255, 255, 255, 0.08)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              color: '#fff',
              padding: '0.6rem 1.2rem',
              borderRadius: '10px',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              cursor: 'pointer',
              fontWeight: 600
            }}
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>

          <button
            onClick={handleLogout}
            style={{
              background: 'rgba(244, 63, 94, 0.15)',
              border: '1px solid #f43f5e',
              color: '#fda4af',
              padding: '0.6rem 1.2rem',
              borderRadius: '10px',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              cursor: 'pointer',
              fontWeight: 600
            }}
          >
            <LogOut size={16} />
            Logout
          </button>
        </div>
      </header>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '16px', margin: '24px 0 16px 0' }}>
        <button
          onClick={() => setActiveTab('users')}
          style={{
            padding: '12px 24px',
            borderRadius: '12px',
            border: 'none',
            backgroundColor: activeTab === 'users' ? '#4361ee' : '#1e293b',
            color: '#fff',
            fontWeight: 700,
            cursor: 'pointer'
          }}
        >
          👥 User Approvals & Payments ({users.filter(u => !u.is_approved).length} Pending)
        </button>

        <button
          onClick={() => setActiveTab('analytics')}
          style={{
            padding: '12px 24px',
            borderRadius: '12px',
            border: 'none',
            backgroundColor: activeTab === 'analytics' ? '#4361ee' : '#1e293b',
            color: '#fff',
            fontWeight: 700,
            cursor: 'pointer'
          }}
        >
          📊 Practice Session Analytics
        </button>
      </div>

      {activeTab === 'users' ? (
        <div style={{ backgroundColor: '#1e293b', borderRadius: '20px', padding: '24px', border: '1px solid rgba(255,255,255,0.05)' }}>
          <h2 style={{ color: '#fff', fontSize: '18px', marginBottom: '16px', fontWeight: 700 }}>
            Student Registrations & Monthly Fee Verification
          </h2>

          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', color: '#cbd5e1', fontSize: '14px' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid #334155', textAlign: 'left' }}>
                  <th style={{ padding: '12px' }}>User Details</th>
                  <th style={{ padding: '12px' }}>Registration Month</th>
                  <th style={{ padding: '12px' }}>Payment Screenshot</th>
                  <th style={{ padding: '12px' }}>Fee Expiry Status</th>
                  <th style={{ padding: '12px' }}>Approval Action</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <td style={{ padding: '16px 12px' }}>
                      <div style={{ fontWeight: 700, color: '#fff' }}>{u.username}</div>
                      <div style={{ fontSize: '12px', color: '#94a3b8' }}>{u.email}</div>
                    </td>
                    <td style={{ padding: '16px 12px' }}>
                      {u.registration_month}
                    </td>
                    <td style={{ padding: '16px 12px' }}>
                      {u.registration_screenshot ? (
                        <button
                          onClick={() => setSelectedImage(`${API_URL}${u.registration_screenshot}`)}
                          style={{
                            backgroundColor: 'rgba(6, 182, 212, 0.15)',
                            border: '1px solid #06b6d4',
                            color: '#38bdf8',
                            padding: '6px 12px',
                            borderRadius: '8px',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px',
                            fontSize: '12px',
                            fontWeight: 600
                          }}
                        >
                          <Eye size={14} /> View Screenshot
                        </button>
                      ) : (
                        <span style={{ color: '#64748b' }}>No Screenshot</span>
                      )}
                    </td>
                    <td style={{ padding: '16px 12px' }}>
                      <span style={{
                        padding: '6px 12px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: 700,
                        backgroundColor: u.payment_status_badge === 'green' ? 'rgba(16,185,129,0.2)' : (u.payment_status_badge === 'orange' ? 'rgba(245,158,11,0.2)' : 'rgba(244,63,94,0.2)'),
                        color: u.payment_status_badge === 'green' ? '#34d399' : (u.payment_status_badge === 'orange' ? '#fbbf24' : '#f87171'),
                        border: `1px solid ${u.payment_status_badge === 'green' ? '#10b981' : (u.payment_status_badge === 'orange' ? '#f59e0b' : '#f43f5e')}`
                      }}>
                        ● {u.status_text}
                      </span>
                    </td>
                    <td style={{ padding: '16px 12px' }}>
                      {!u.is_approved ? (
                        <button
                          onClick={() => handleApproveUser(u)}
                          style={{
                            backgroundColor: '#10b981',
                            color: '#fff',
                            border: 'none',
                            padding: '8px 16px',
                            borderRadius: '8px',
                            fontWeight: 700,
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '6px'
                          }}
                        >
                          <Check size={16} /> Approve User
                        </button>
                      ) : (
                        u.is_active ? (
                          <button
                            onClick={() => handleDeactivateUser(u)}
                            style={{
                              backgroundColor: 'rgba(244,63,94,0.2)',
                              border: '1px solid #f43f5e',
                              color: '#f87171',
                              padding: '6px 12px',
                              borderRadius: '8px',
                              fontWeight: 600,
                              cursor: 'pointer'
                            }}
                          >
                            Deactivate
                          </button>
                        ) : (
                          <button
                            onClick={() => handleApproveUser(u)}
                            style={{
                              backgroundColor: '#4361ee',
                              color: '#fff',
                              border: 'none',
                              padding: '6px 12px',
                              borderRadius: '8px',
                              fontWeight: 600,
                              cursor: 'pointer'
                            }}
                          >
                            Re-activate
                          </button>
                        )
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        /* Analytics View */
        <div style={{ backgroundColor: '#1e293b', borderRadius: '20px', padding: '24px', border: '1px solid rgba(255,255,255,0.05)' }}>
          <div className="stats-grid" style={{ marginBottom: '24px' }}>
            <div className="stat-card">
              <div className="stat-header"><span>Total Attempts</span><Activity size={18} color="#06b6d4" /></div>
              <div className="stat-value">{stats.total_sessions}</div>
            </div>
            <div className="stat-card">
              <div className="stat-header"><span>Passed Attempts</span><CheckCircle2 size={18} color="#10b981" /></div>
              <div className="stat-value" style={{ color: '#10b981' }}>{stats.passed_sessions}</div>
            </div>
            <div className="stat-card">
              <div className="stat-header"><span>Pass Rate</span><Award size={18} color="#a855f7" /></div>
              <div className="stat-value" style={{ color: '#a855f7' }}>{stats.pass_rate_pct}%</div>
            </div>
          </div>

          <h2 style={{ color: '#fff', fontSize: '18px', marginBottom: '16px', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Volume2 size={20} color="#06b6d4" /> Learner Practice Session History
          </h2>

          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', color: '#cbd5e1', fontSize: '14px' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid #334155', textAlign: 'left' }}>
                  <th style={{ padding: '12px' }}>Learner Name</th>
                  <th style={{ padding: '12px' }}>Alphabet</th>
                  <th style={{ padding: '12px' }}>Spoken Sound</th>
                  <th style={{ padding: '12px' }}>Accuracy %</th>
                  <th style={{ padding: '12px' }}>Evaluation Result</th>
                  <th style={{ padding: '12px' }}>Date & Time</th>
                </tr>
              </thead>
              <tbody>
                {stats.recent_logs && stats.recent_logs.length > 0 ? (
                  stats.recent_logs.map((log, index) => {
                    const isPassed = Boolean(log.passed === true || log.passed === 1);
                    return (
                      <tr key={log.id || index} style={{ borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                        <td style={{ padding: '14px 12px' }}>
                          <div style={{ fontWeight: 700, color: '#60a5fa', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <Users size={16} /> {log.student || 'Learner'}
                          </div>
                        </td>
                        <td style={{ padding: '14px 12px' }}>
                          <span style={{
                            padding: '4px 10px',
                            borderRadius: '8px',
                            backgroundColor: 'rgba(99, 102, 241, 0.2)',
                            color: '#818cf8',
                            fontWeight: 800,
                            fontSize: '14px',
                            border: '1px solid rgba(99, 102, 241, 0.4)'
                          }}>
                            {log.alphabet ? log.alphabet.toUpperCase() : '-'}
                          </span>
                        </td>
                        <td style={{ padding: '14px 12px', fontStyle: 'italic', color: '#e2e8f0' }}>
                          "{log.spoken_sound || log.whisper_transcription || '-'}"
                        </td>
                        <td style={{ padding: '14px 12px', fontWeight: 700 }}>
                          <span style={{
                            color: log.accuracy >= 90 ? '#34d399' : (log.accuracy >= 60 ? '#fbbf24' : '#f87171')
                          }}>
                            {log.accuracy}%
                          </span>
                        </td>
                        <td style={{ padding: '14px 12px' }}>
                          <span style={{
                            padding: '4px 12px',
                            borderRadius: '20px',
                            fontSize: '12px',
                            fontWeight: 700,
                            backgroundColor: isPassed ? 'rgba(16,185,129,0.2)' : 'rgba(244,63,94,0.2)',
                            color: isPassed ? '#34d399' : '#f87171',
                            border: `1px solid ${isPassed ? '#10b981' : '#f43f5e'}`,
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '4px'
                          }}>
                            {isPassed ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />}
                            {isPassed ? 'Passed' : 'Needs Practice'}
                          </span>
                        </td>
                        <td style={{ padding: '14px 12px', color: '#94a3b8', fontSize: '13px' }}>
                          {log.timestamp || '-'}
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: '#64748b' }}>
                      No learner practice records logged yet.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Screenshot Viewer Modal */}
      {selectedImage && (
        <div style={{
          position: 'fixed',
          inset: 0,
          backgroundColor: 'rgba(0,0,0,0.85)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }}>
          <div style={{ position: 'relative', backgroundColor: '#1e293b', padding: '20px', borderRadius: '20px', maxWidth: '90%', maxHeight: '90%' }}>
            <button
              onClick={() => setSelectedImage(null)}
              style={{ position: 'absolute', top: '10px', right: '10px', background: 'red', color: '#fff', border: 'none', borderRadius: '50%', width: '32px', height: '32px', cursor: 'pointer' }}
            >
              ✕
            </button>
            <img src={selectedImage} alt="Payment Proof" style={{ maxWidth: '100%', maxHeight: '80vh', borderRadius: '12px' }} />
          </div>
        </div>
      )}
    </main>
  );
}
