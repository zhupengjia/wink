package supabase

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

// Client wraps Supabase REST API operations
type Client struct {
	baseURL    string
	serviceKey string
	httpClient *http.Client
}

// NewClient creates a new Supabase client
func NewClient() *Client {
	return &Client{
		baseURL:    os.Getenv("SUPABASE_URL") + "/rest/v1",
		serviceKey: os.Getenv("SUPABASE_SERVICE_KEY"),
		httpClient: &http.Client{},
	}
}

// QueryBuilder builds and executes Supabase queries
type QueryBuilder struct {
	client     *Client
	table      string
	selectCols string
	filters    map[string]interface{}
	insertData interface{}
	updateData interface{}
	single     bool
}

// From starts a query on a table
func (c *Client) From(table string) *QueryBuilder {
	return &QueryBuilder{
		client:  c,
		table:   table,
		filters: make(map[string]interface{}),
	}
}

// Select specifies columns to retrieve
func (q *QueryBuilder) Select(columns string) *QueryBuilder {
	q.selectCols = columns
	return q
}

// Insert sets data to insert
func (q *QueryBuilder) Insert(data interface{}) *QueryBuilder {
	q.insertData = data
	return q
}

// Update sets data to update
func (q *QueryBuilder) Update(data interface{}) *QueryBuilder {
	q.updateData = data
	return q
}

// Eq adds an equality filter
func (q *QueryBuilder) Eq(column string, value interface{}) *QueryBuilder {
	q.filters[column] = value
	return q
}

// Single expects a single result
func (q *QueryBuilder) Single() *QueryBuilder {
	q.single = true
	return q
}

// Execute runs the query
func (q *QueryBuilder) Execute() ([]byte, error) {
	var method string
	var body io.Reader
	var url string

	switch {
	case q.insertData != nil:
		method = "POST"
		data, err := json.Marshal(q.insertData)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal insert data: %w", err)
		}
		body = bytes.NewReader(data)
		url = fmt.Sprintf("%s/%s", q.client.baseURL, q.table)

	case q.updateData != nil:
		method = "PATCH"
		data, err := json.Marshal(q.updateData)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal update data: %w", err)
		}
		body = bytes.NewReader(data)
		url = q.buildURL()

	default:
		method = "GET"
		url = q.buildURL()
	}

	req, err := http.NewRequest(method, url, body)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", q.client.serviceKey)
	req.Header.Set("Authorization", "Bearer "+q.client.serviceKey)
	req.Header.Set("Content-Type", "application/json")

	if q.single {
		req.Header.Set("Accept", "application/vnd.pgrst.object+json")
	}

	if q.insertData != nil || q.updateData != nil {
		req.Header.Set("Prefer", "return=representation")
	}

	resp, err := q.client.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("supabase error (%d): %s", resp.StatusCode, string(respBody))
	}

	return respBody, nil
}

func (q *QueryBuilder) buildURL() string {
	url := fmt.Sprintf("%s/%s", q.client.baseURL, q.table)

	if q.selectCols != "" {
		url += "?select=" + q.selectCols
	}

	for col, val := range q.filters {
		separator := "&"
		if q.selectCols == "" && len(q.filters) == 1 {
			separator = "?"
		}
		url += fmt.Sprintf("%s%s=eq.%v", separator, col, val)
	}

	return url
}

// Storage client for file operations
type StorageClient struct {
	baseURL    string
	serviceKey string
	httpClient *http.Client
}

// NewStorageClient creates a new storage client
func NewStorageClient() *StorageClient {
	return &StorageClient{
		baseURL:    os.Getenv("SUPABASE_URL") + "/storage/v1",
		serviceKey: os.Getenv("SUPABASE_SERVICE_KEY"),
		httpClient: &http.Client{},
	}
}

// Upload uploads a file to a bucket
func (s *StorageClient) Upload(bucket, path string, data []byte, contentType string) (string, error) {
	url := fmt.Sprintf("%s/object/%s/%s", s.baseURL, bucket, path)

	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return "", fmt.Errorf("failed to create upload request: %w", err)
	}

	req.Header.Set("apikey", s.serviceKey)
	req.Header.Set("Authorization", "Bearer "+s.serviceKey)
	req.Header.Set("Content-Type", contentType)

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to upload: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("upload failed (%d): %s", resp.StatusCode, string(body))
	}

	// Return public URL
	publicURL := fmt.Sprintf("%s/object/public/%s/%s", s.baseURL, bucket, path)
	return publicURL, nil
}

// GetPublicURL returns the public URL for a file
func (s *StorageClient) GetPublicURL(bucket, path string) string {
	return fmt.Sprintf("%s/object/public/%s/%s", s.baseURL, bucket, path)
}
