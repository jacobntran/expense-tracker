const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { Pool } = require('pg');  // Importing pg for PostgreSQL connection

const app = express();
const port = 3000;

app.use(bodyParser.json());
app.use(cors());

// PostgreSQL connection settings (replace with your own RDS PostgreSQL details)
const pool = new Pool({
    user: 'yourUsername',        // your PostgreSQL username
    host: 'yourRDSHost',         // your RDS endpoint
    database: 'yourDatabaseName', // your database name
    password: 'yourPassword',     // your database password
    port: 5432,                   // default PostgreSQL port
});

// Create a table for expenses if it doesn't exist (run once)
pool.query(`
  CREATE TABLE IF NOT EXISTS expenses (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    category VARCHAR(255) NOT NULL
  );
`, (err, res) => {
    if (err) {
        console.error('Error creating table:', err);
    } else {
        console.log('Expense table ready.');
    }
});

// Get all expenses
app.get('/api/expenses', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM expenses');
        res.json(result.rows);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// Add a new expense
app.post('/api/expenses', async (req, res) => {
    const { name, amount, category } = req.body;

    if (!name || !amount || !category) {
        return res.status(400).json({ message: 'All fields are required.' });
    }

    try {
        const result = await pool.query(
            'INSERT INTO expenses (name, amount, category) VALUES ($1, $2, $3) RETURNING *',
            [name, amount, category]
        );
        res.status(201).json(result.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// Update an expense
app.put('/api/expenses/:id', async (req, res) => {
    const { id } = req.params;
    const { name, amount, category } = req.body;

    if (!name || !amount || !category) {
        return res.status(400).json({ message: 'All fields are required.' });
    }

    try {
        const result = await pool.query(
            'UPDATE expenses SET name = $1, amount = $2, category = $3 WHERE id = $4 RETURNING *',
            [name, amount, category, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Expense not found.' });
        }

        res.json(result.rows[0]);
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

// Delete an expense
app.delete('/api/expenses/:id', async (req, res) => {
    const { id } = req.params;

    try {
        const result = await pool.query('DELETE FROM expenses WHERE id = $1 RETURNING *', [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ message: 'Expense not found.' });
        }

        res.status(204).send();
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error' });
    }
});

app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
