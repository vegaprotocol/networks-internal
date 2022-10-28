package cmd

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"
	"github.com/vegaprotocol/devopstools/networktools"
	"go.uber.org/zap"
)

type UpdateNodesDataArgs struct {
	RootArgs
}

var updateNodesDataArgs UpdateNodesDataArgs

var updateNodesDataCmd = &cobra.Command{
	Use:   "update-nodes-data",
	Short: "Pull latest information about nodes from HashiCorp Vault and stores in local [network name]/templates/nodes.json",
	Run: func(cmd *cobra.Command, args []string) {
		updateNodesDataArgs.RootArgs = rootArgs
		if err := RunUpdateNodesData(updateNodesDataArgs); err != nil {
			rootArgs.Logger.Error("Error", zap.Error(err))
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(updateNodesDataCmd)
}

func RunUpdateNodesData(args UpdateNodesDataArgs) error {
	nodeSecretStore, err := args.GetNodeSecretStore()
	if err != nil {
		return err
	}

	nodeSecrets, err := nodeSecretStore.GetAllVegaNode(args.VegaNetworkName)
	if err != nil {
		return err
	}

	networkTools, err := networktools.NewNetworkTools(args.VegaNetworkName, args.Logger)
	if err != nil {
		return err
	}

	data := map[string]*VegaNodeConfig{}

	for nodeId, node := range nodeSecrets {
		data[nodeId] = &VegaNodeConfig{
			Node:                       nodeId,
			URL:                        networkTools.GetNodeURL(nodeId),
			EthereumAddress:            node.EthereumAddress,
			VegaPubKey:                 node.VegaPubKey,
			Id:                         node.VegaId,
			TendermintNodeId:           node.TendermintNodeId,
			TendermintNodePubKey:       node.TendermintNodePubKey,
			TendermintValidatorAddress: node.TendermintValidatorAddress,
			TendermintValidatorPubKey:  node.TendermintValidatorPubKey,
			InfoURL:                    node.InfoURL,
			Country:                    node.Country,
			AvatarURL:                  node.AvatarURL,
			Name:                       node.Name,
		}
	}

	byteNodes, err := json.MarshalIndent(data, "", "\t")
	if err != nil {
		return fmt.Errorf("failed to conver nodes data to json %w", err)
	}
	// Store to file
	currPath, err := os.Getwd()
	if err != nil {
		return err
	}
	fileWithNodes := filepath.Join(currPath, args.VegaNetworkName, "templates", "nodes.json")
	if err = ioutil.WriteFile(fileWithNodes, byteNodes, 0644); err != nil {
		return fmt.Errorf("failed to save nodes data to file %s. %w", fileWithNodes, err)
	}

	args.Logger.Info("successfully stored nodes data", zap.String("file", fileWithNodes), zap.Int("number of nodes", len(data)))
	return nil
}
